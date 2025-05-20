import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart'; // 🔑 권한 요청 패키지 추가

class NotificationServiceTodolist {
  static final NotificationServiceTodolist _notificationService = NotificationServiceTodolist._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationServiceTodolist() {
    return _notificationService;
  }

  NotificationServiceTodolist._internal();

  /// 초기화 + 정확 알림 권한 요청
  Future<void> init() async {
    // 타임존 초기화
    tz_data.initializeTimeZones();

    // 디버그용 로그
    log('🌍 타임존 초기화 완료: ${tz.local}');

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

    log('📱 알림 서비스 초기화 완료');

    // 🔒 정확한 알림 권한 요청 (Android 12+)
    await requestExactAlarmPermissionIfNeeded();

    // 알림 설정 중요 채널 생성 (Android)
    await _createNotificationChannel();
  }

  // 중요한 알림 채널 생성 (Android)
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'custom_reminder_channel', // id
      '사용자 설정 알림', // name
      description: '사용자가 설정한 시간 전 알림', // description
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    log('📢 알림 채널 생성 완료');
  }

  // 알림 클릭 시 처리
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    log('🔔 알림 탭됨: ${notificationResponse.payload}');
  }

  /// 🔒 정확 알림 권한 요청 (Android 12 이상)
  Future<void> requestExactAlarmPermissionIfNeeded() async {
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isGranted) {
          log('✅ 알림 권한 허용');
        } else {
          log('❌ 알림 권한 거부');
        }
      } else {
        log('✅ 알림 권한 이미 허용됨');
      }
    } catch (e) {
      log('❌ 권한 요청 오류: $e');
    }
  }

  // reminder 문자열을 분 단위로 변환하는 헬퍼 함수
  int _parseReminderToMinutes(String reminder, {int? customMinutes}) {
    log('⏰ 알림 파싱: $reminder, 커스텀: $customMinutes');
    switch (reminder) {
      case '1분 전':
        return 1;
      case '5분 전':
        return 5;
      case '10분 전':
        return 10;
      case '30분 전':
        return 30;
      case '1시간 전':
        return 60;
      case '기타':
        return customMinutes ?? 0; // customMinutes가 null이면 0
      default:
      // 커스텀 시간이 숫자 + "분 전" 형태일 경우
        if (reminder.endsWith('분 전')) {
          final minutes = reminder.split('분 전')[0].trim();
          if (int.tryParse(minutes) != null) {
            return int.parse(minutes);
          }
        }
        return 0;
    }
  }

  // ✅ 문자열 기반으로 시작 전 알림 예약 (reminder 기준)
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required DateTime startDateTime,
    required String reminder,
    int? customMinutes, // '기타'일 경우 사용자가 직접 입력한 값
  }) async {
    final minutesBefore = _parseReminderToMinutes(reminder, customMinutes: customMinutes);
    final scheduledTime = startDateTime.subtract(Duration(minutes: minutesBefore));

    log('🔔 알림 예약 시도: ID=$id, 제목=$title');
    log('⏰ 일정 시작=$startDateTime, ${minutesBefore}분 전 알림=${scheduledTime}');

    if (scheduledTime.isAfter(DateTime.now())) {
      try {
        final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

        log('🕒 알림 설정 시간(TZ): $tzScheduledTime');

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '$title',
          '🔔 $minutesBefore분 후에 시작돼요.',
          tzScheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'custom_reminder_channel',
              '할 일 미리 알림',
              channelDescription: '사용자가 설정한 시간 전 알림',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              visibility: NotificationVisibility.public,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'event_$id',
        );
        log('✅ 알림 예약 성공: ID=$id, 제목=$title');
      } catch (e) {
        log('❌ 알림 예약 실패: $e');
      }
    } else {
      log('⚠️ 알림 시간이 현재보다 이전이라 예약되지 않음: $scheduledTime');
    }
  }

  // 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    log('🗑️ 알림 취소됨: ID=$id');
  }

  // 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    log('🗑️ 모든 알림 취소됨');
  }
}