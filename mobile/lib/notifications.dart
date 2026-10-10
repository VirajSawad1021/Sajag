// Follow-ups: Gemma pulls promised dates out of the chat ("delivery within 3 days"); Sajag turns verified ones
// into reminders on the phone ("Did your order arrive?"). Tapping a reminder opens the case.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'l10n.dart';
import 'models.dart';

class Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  /// Called when a notification (or one of its buttons) is tapped. [action] is 'arrived', 'not_arrived' or null.
  void Function(String caseId, String? action)? onOpenCase;
  NotificationResponse? _launch; // a tap that started the app; handled once the UI is ready

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sajag_followups',
      'Sajag follow-ups',
      channelDescription: 'Reminders to check deliveries, deadlines and recovery steps',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Delivery check-ins carry Yes / Not yet buttons (they open the app, which then acts on the answer).
  static NotificationDetails _checkIn() => NotificationDetails(
        android: AndroidNotificationDetails(
          'sajag_followups',
          'Sajag follow-ups',
          channelDescription: 'Reminders to check deliveries, deadlines and recovery steps',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('arrived', lang.ne ? 'हो, आयो' : 'Yes, arrived', showsUserInterface: true, cancelNotification: true),
            AndroidNotificationAction('not_arrived', lang.ne ? 'अहिलेसम्म आएन' : 'Not yet', showsUserInterface: true, cancelNotification: true),
          ],
        ),
      );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) onOpenCase?.call(r.payload!, r.actionId);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _launch = launch!.notificationResponse;
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Act on a notification tap that launched the app (call after [onOpenCase] is set and the UI exists).
  void handleLaunch() {
    final r = _launch;
    _launch = null;
    if (r?.payload != null) onOpenCase?.call(r!.payload!, r.actionId);
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  int _id(String caseId, String key) => (caseId + key).hashCode & 0x7fffffff;

  /// Schedule a check-in at 7 pm Nepal time on each verified future deadline. Returns what was scheduled.
  Future<List<({DateTime when, String what})>> scheduleDeadlines(SajagCase c) async {
    final scheduled = <({DateTime when, String what})>[];
    final a = c.latest?.a;
    if (!_ready || a == null) return scheduled;
    await requestPermission();
    final now = tz.TZDateTime.now(tz.local);
    for (final d in a.deadlines) {
      final due = DateTime.tryParse('${d['due'] ?? ''}');
      if (due == null || d['grounded'] != true) continue;
      final at = tz.TZDateTime(tz.local, due.year, due.month, due.day, 19);
      if (at.isBefore(now)) continue;
      final what = '${lang.ne ? (d['what_ne'] ?? d['what_en']) : d['what_en']}';
      await _plugin.zonedSchedule(
        id: _id(c.id, 'deadline:${d['due']}:$what'),
        scheduledDate: at,
        notificationDetails: _checkIn(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: lang.ne ? 'Sajag: आज फलोअप गर्ने दिन' : 'Sajag: follow-up due today',
        body: lang.ne
            ? '${c.title} — $what। सामान आयो? नआए रिकभरी सुरु गर्नुहोस्।'
            : '${c.title} — $what. Did it arrive? If not, start recovery.',
        payload: c.id,
      );
      scheduled.add((when: at, what: what));
    }
    return scheduled;
  }

  /// A reminder the user sets from the recovery plan (e.g. "check whether the wallet replied").
  Future<void> remindIn(SajagCase c, Duration after, String title, String body, String key) async {
    if (!_ready) return;
    await requestPermission();
    await _plugin.zonedSchedule(
      id: _id(c.id, key),
      scheduledDate: tz.TZDateTime.now(tz.local).add(after),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: c.id,
    );
  }

  /// Immediate notification (used by the demo to show what a follow-up looks like).
  Future<void> showNow(SajagCase c, String title, String body) async {
    if (!_ready) return;
    await requestPermission();
    await _plugin.show(id: _id(c.id, 'now'), title: title, body: body, notificationDetails: _checkIn(), payload: c.id);
  }
}

final reminders = Reminders();
