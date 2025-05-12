import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    // 타임존 초기화
    tz_data.initializeTimeZones();

    // Android 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정 (최신 버전에서는 onDidReceiveLocalNotification 제거됨)
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // 전체 초기화 설정
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 플러그인 초기화
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  // 알림 클릭 시 처리
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    log('Notification tapped: ${notificationResponse.payload}');
  }

  // 📌 시작 시간 알림 스케줄링
  Future<void> scheduleTaskStartNotification(
      int id, String title, String body, DateTime scheduledDate) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_start_channel',
            'Task Start Notifications',
            channelDescription: 'Notification channel for task start times',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF9D8CFF),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // ✅ 필수
      );
      log('✅ Start notification scheduled for task $id at $scheduledDate');
    } catch (e) {
      log('❌ Error scheduling start notification: $e');
    }
  }

  // 📌 마감 시간 알림 스케줄링
  Future<void> scheduleTaskDueNotification(
      int id, String title, String body, DateTime dueDate) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 1000, // 충돌 방지를 위한 ID 오프셋
        title,
        body,
        tz.TZDateTime.from(dueDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_due_channel',
            'Task Due Notifications',
            channelDescription: 'Notification channel for task due times',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFFF9D8C),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // ✅ 필수
      );
      log('✅ Due notification scheduled for task $id at $dueDate');
    } catch (e) {
      log('❌ Error scheduling due notification: $e');
    }
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
