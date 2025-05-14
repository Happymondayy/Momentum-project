import 'package:flutter/material.dart';
import 'package:momentum_planner/Todolist/screens/notification_service.dart';

class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('알림 테스트')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now().add(Duration(seconds: 10));
                await NotificationService().scheduleStartNotification(
                  1,
                  '테스트 일정',
                  now,
                );
              },
              child: Text('🔔 10초 후 알림 테스트'),
            ),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now().add(Duration(seconds: 15));
                await NotificationService().scheduleDeadlineNotification(
                  2,
                  '테스트 마감',
                  now,
                );
              },
              child: Text('📌 마감 테스트 알림'),
            ),
            ElevatedButton(
              onPressed: () async {
                await NotificationService().cancelAllNotifications();
              },
              child: Text('❌ 모든 알림 취소'),
            ),
          ],
        ),
      ),
    );
  }
}
