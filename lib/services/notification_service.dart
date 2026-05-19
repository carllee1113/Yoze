import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../theme/rainbow_colors.dart';
import '../database/database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _tts.setLanguage('zh-TW');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);

    const androidChannel = AndroidNotificationChannel(
      'medication_reminder',
      '吃藥提醒',
      description: '服藥時間提醒通知',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    unawaited(_handleNotificationTap(response));
  }

  static Future<void> _handleNotificationTap(
    NotificationResponse response,
  ) async {
    final payload = response.payload ?? '';
    final medicationId = _extractMedicationId(payload, response.id);
    if (medicationId == null) {
      return;
    }

    final actionId = response.actionId;
    if (actionId == 'confirm') {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await DatabaseHelper.confirmDose(medicationId, today, 0);
      return;
    }

    if (actionId == 'snooze') {
      await _scheduleSnoozeReminder(medicationId);
    }
  }

  static Future<void> scheduleMedicationReminder({
    required int medicationId,
    required String medicationName,
    required int colorIndex,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final emojis = ['🔴', '🟡', '🔵', '🟢', '🟠', '🟣', '🩵'];
    final labels = RainbowColors.fullLabels;
    final colorEmoji = emojis[colorIndex % emojis.length];
    final colorLabel = labels[colorIndex % labels.length];
    final body = '$colorEmoji $colorLabel — $medicationName';

    final androidDetails = AndroidNotificationDetails(
      'medication_reminder',
      '吃藥提醒',
      channelDescription: '服藥時間提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('confirm', '已吃', showsUserInterface: true),
        const AndroidNotificationAction('snooze', '稍後提醒'),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    await _plugin.zonedSchedule(
      medicationId,
      '🔴 該吃藥了！',
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'medication_$medicationId',
    );
  }

  static Future<void> _configureLocalTimeZone() async {
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Keep timezone's default local location as fallback.
    }
  }

  static int? _extractMedicationId(String payload, int? id) {
    final payloadMatch = RegExp(r'medication_(\d+)').firstMatch(payload);
    if (payloadMatch != null) {
      return int.tryParse(payloadMatch.group(1)!);
    }
    return id;
  }

  static Future<void> _scheduleSnoozeReminder(int medicationId) async {
    final snoozeId = medicationId + 1000000;
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminder',
        '吃藥提醒',
        channelDescription: '服藥時間提醒通知',
        importance: Importance.max,
        priority: Priority.max,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      snoozeId,
      '⏰ 10 分鐘後提醒',
      '請記得按時服藥',
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'medication_$medicationId',
    );
  }

  static Future<void> cancelReminder(int medicationId) async {
    await _plugin.cancel(medicationId);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> speak(String text) async {
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.speak(text);
    } catch (_) {
      // TTS not available
    }
  }
}
