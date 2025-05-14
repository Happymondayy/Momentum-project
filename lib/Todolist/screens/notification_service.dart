import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart'; // 🔑 권한 요청 패키지 추가

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  /// 초기화 + 정확 알림 권한 요청
  Future<void> init() async {
    // 타임존 초기화
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // 🔒 정확한 알림 권한 요청 (Android 12+)
    await requestExactAlarmPermissionIfNeeded();
  }

  // 알림 클릭 시 처리
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    log('Notification tapped: ${notificationResponse.payload}');
  }

  /// 🔒 정확 알림 권한 요청 (Android 12 이상)
  Future<void> requestExactAlarmPermissionIfNeeded() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      final result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) {
        log('✅ 정확 알림 권한 허용됨');
      } else {
        log('❌ 정확 알림 권한 거부됨');
      }
    } else {
      log('✅ 정확 알림 권한 이미 허용됨');
    }
  }

  // ✅ 시작 10분 전 알림 예약
  Future<void> scheduleStartNotification(
      int id, String title, DateTime startTime) async {
    final scheduledTime = startTime.subtract(Duration(minutes: 10));
    if (scheduledTime.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        '곧 시작할 일정',
        '$title 일정이 10분 후에 시작돼요.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'start_soon_channel',
            '10분 전 알림',
            channelDescription: '시작 10분 전 알림 채널',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      log('✅ 10분 전 알림 예약됨: $title ($scheduledTime)');
    }
  }

  // ✅ 마감 하루 전 + 당일 알림 예약
  Future<void> scheduleDeadlineNotification(
      int id, String title, DateTime deadline) async {
    final now = DateTime.now();
    final oneDayBefore = DateTime(deadline.year, deadline.month, deadline.day - 1, 9, 0);
    final onDeadline = DateTime(deadline.year, deadline.month, deadline.day, 9, 0);

    if (oneDayBefore.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 1000,
        '내일 마감될 일정',
        '$title 일정이 내일 마감돼요.',
        tz.TZDateTime.from(oneDayBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'due_1day_channel',
            '마감 하루 전 알림',
            channelDescription: '하루 전 마감 알림 채널',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      log('✅ 하루 전 마감 알림 예약됨: $title ($oneDayBefore)');
    }

    if (onDeadline.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 2000,
        '오늘 마감되는 일정',
        '$title 일정이 오늘 마감돼요.',
        tz.TZDateTime.from(onDeadline, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'due_today_channel',
            '마감 당일 알림',
            channelDescription: '당일 마감 알림 채널',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      log('✅ 당일 마감 알림 예약됨: $title ($onDeadline)');
    }
  }

  Future<void> scheduleCustomReminderNotification(int id, String title, DateTime scheduledTime, int minutesBefore) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '$minutesBefore분 전 알림',
      '$title 일정이 $minutesBefore분 후에 시작됩니다.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'custom_reminder_channel',
          '사용자 설정 알림',
          channelDescription: '사용자가 설정한 시간 전 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }


  // 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
