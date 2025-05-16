import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Function(String)? _onNotificationClick;

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  void setOnNotificationClickListener(Function(String) listener) {  // <-- init() 함수 바로 위에 추가
    _onNotificationClick = listener;
  }

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(android: android, iOS: ios);

    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _requestPermissions();
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) {
    log('🔔 Notification tapped: ${response.payload}');
    if (_onNotificationClick != null && response.payload != null) {
      _onNotificationClick!(response.payload!);
    }
  }

  Future<void> _requestPermissions() async {
    // Android 12+: 정확 알림 권한
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Android 13+: 알림 권한
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> scheduleStartNotification(int id, String title, DateTime startTime) async {
    final scheduledTime = startTime.subtract(Duration(minutes: 10));
    if (scheduledTime.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        '⏰ 곧 시작할 일정',
        '$title 일정이 10분 후에 시작돼요.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'start_channel',
            '시작 알림',
            channelDescription: '일정 시작 전 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> scheduleDeadlineNotification(int id, String title, DateTime deadline) async {
    final now = DateTime.now();
    final oneDayBefore = DateTime(deadline.year, deadline.month, deadline.day - 1, 9);
    final onDeadline = DateTime(deadline.year, deadline.month, deadline.day, 9);

    if (oneDayBefore.isAfter(now)) {
      await _zonedNotify(
        id + 1000,
        '📌 내일 마감될 일정',
        '$title 일정이 내일 마감돼요.',
        oneDayBefore,
      );
    }

    if (onDeadline.isAfter(now)) {
      await _zonedNotify(
        id + 2000,
        '📌 오늘 마감되는 일정',
        '$title 일정이 오늘 마감돼요.',
        onDeadline,
      );
    }
  }

  Future<void> scheduleCustomReminderNotification(
      int id, String title, DateTime scheduledTime, int minutesBefore) async {
    final targetTime = scheduledTime.subtract(Duration(minutes: minutesBefore));
    if (targetTime.isAfter(DateTime.now())) {
      await _zonedNotify(
        id,
        '⏰ $minutesBefore분 전 알림',
        '$title 일정이 $minutesBefore분 후에 시작됩니다.',
        targetTime,
      );
    }
  }

  Future<void> scheduleDailyRoutineNotification(int id, String message, TimeOfDay time) async {
    final now = DateTime.now();
    final scheduleDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final scheduledTime = tz.TZDateTime.from(scheduleDateTime.isBefore(now)
        ? scheduleDateTime.add(Duration(days: 1))
        : scheduleDateTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '📚 오늘도 일정 작성하셨나요?',
      message,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'routine_channel',
          '학습 루틴 알림',
          channelDescription: '매일 같은 시간에 루틴 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleMissedGoalNotification(int id) async {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, 21, 0); // 오후 9시

    if (scheduledTime.isAfter(now)) {
      await _zonedNotify(
        id,
        '🥲 오늘 목표를 잊으셨나요?',
        '오늘 설정한 일정을 아직 완료하지 않으셨어요!',
        scheduledTime,
      );
    }
  }

  Future<void> scheduleStreakReminder(int id, int streakDays) async {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, 20, 0); // 오후 8시

    if (scheduledTime.isAfter(now)) {
      await _zonedNotify(
        id,
        '🔥 $streakDays일 연속 일정 완료 중!',
        '꾸준함은 힘입니다! 오늘도 기록을 이어가봐요.',
        scheduledTime,
      );
    }
  }

  Future<void> scheduleCompletionCelebrate(int id, String title) async {
    final now = DateTime.now();
    await _zonedNotify(
      id,
      '🎉 일정 완료!',
      '$title 일정을 성공적으로 마쳤어요! 수고했어요 👏',
      now.add(Duration(seconds: 2)),
    );
  }

  Future<void> _zonedNotify(int id, String title, String body, DateTime time) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(time, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          '기본 알림',
          channelDescription: '기본 알림 채널',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // ✅ 목표 미달 알림 (매일 밤 9시 확인)
  Future<void> scheduleDailyGoalCheck(int id) async {
    final now = DateTime.now();
    final next9pm = DateTime(now.year, now.month, now.day, 21);
    final scheduleTime = next9pm.isAfter(now) ? next9pm : next9pm.add(Duration(days: 1));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '오늘 목표 확인!',
      '오늘 일정을 다 못했나요? 확인해보세요!',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('goal_check', '목표 확인 알림',
          channelDescription: '목표 미달 시 알림',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //uiLocalNotificationDateInterpretation:
      //UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

// ✅ 학습 루틴 알림 (매일 오전 8시)
  Future<void> scheduleDailyRoutineReminder(int id) async {
    final now = DateTime.now();
    final next8am = DateTime(now.year, now.month, now.day, 8);
    final scheduleTime = next8am.isAfter(now) ? next8am : next8am.add(Duration(days: 1));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '오늘 일정 등록하셨나요?',
      '매일 조금씩이라도 계획을 세워보세요!',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('routine_reminder', '루틴 알림',
          channelDescription: '매일 루틴 유도 알림',
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //uiLocalNotificationDateInterpretation:
      //UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

// ✅ 성취 축하 알림 (일정 완료 시 호출)
  Future<void> showTaskCompletedNotification(String title) async {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🎉 일정 완료!',
      '$title 일정을 성공적으로 마쳤어요! 잘하셨어요!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'completion_channel',
          '성취 축하 알림',
          channelDescription: '일정 완료 시 축하 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'go_todolist',  // <-- payload 여기에 추가
    );
  }

// ✅ 지속성 강조 (n일 연속 일정 유지 중일 때 호출)
  Future<void> showStreakNotification(int streakDays) async {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🔥 $streakDays일 연속!',
      '$streakDays일 연속으로 계획을 지키고 있어요! 멋져요!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_channel',
          '연속 유지 알림',
          channelDescription: '일정 연속 유지 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

}
