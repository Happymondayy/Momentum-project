import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:momentum_planner/AI/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:momentum_planner/Calendar/screens/calendar_screen.dart';
import 'package:momentum_planner/Diary/screens/diary_screen.dart';
import 'package:momentum_planner/Login/find_ID_page.dart';
import 'package:momentum_planner/Login/find_password_page.dart';
import 'package:momentum_planner/Login/signup_page.dart';
import 'package:momentum_planner/Login/login_page.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';
import 'package:momentum_planner/Settings/settings_page.dart';
import 'package:momentum_planner/Todolist/screens/notification_service.dart';

import 'firebase_options.dart';

import 'dart:async';
import 'package:momentum_planner/Calendar/services/notification_service_calendar.dart';
import 'package:momentum_planner/Calendar/services/notification_service_todolist.dart';
import 'screens/api_test_screen.dart';  // 테스트용

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await NotificationService().init();
    await NotificationService().scheduleDailyGoalCheck(999);
    await NotificationService().scheduleDailyRoutineReminder(998);
    await NotificationService().scheduleDailyRoutineReminder(997);
  } else {
    print("⚠️ 웹에서는 알림 기능을 비활성화합니다.");
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("🔥 Firebase 초기화 성공!");
    } else {
      print("⚡ Firebase가 이미 초기화되었습니다.");
    }
  } catch (e) {
    print("❌ Firebase 초기화 실패: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService notificationService = NotificationService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      notificationService.init();
      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

      notificationService.setOnNotificationClickListener((payload) {
        print('Notification clicked with payload: $payload');

        if (payload == 'go_todolist') {
          navigatorKey.currentState?.pushNamed(
            'Planner/DailyPlannerPage',
            arguments: {'userId': currentUserId ?? ''},
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusMate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansKR',
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: SplashScreen(),
      //home: ApiTestScreen(), //스케쥴러 연결 테스트용
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        final userId = args?['userId'] ?? '';
        final int initialIndex = args?['initialIndex'] ?? 0; // 초기 인덱스 추가

        switch (settings.name) {
          case 'Login/login_page':
            return MaterialPageRoute(builder: (_) => LoginPage());
          case 'Login/signup_page':
            return MaterialPageRoute(builder: (_) => SignupPage());
          case 'Login/find_ID_page':
            return MaterialPageRoute(builder: (_) => FindIdPage());
          case 'Login/find_password_page':
            return MaterialPageRoute(builder: (_) => FindPasswordPage());
          case 'Survey/models/survey_screen':
            return MaterialPageRoute(
              builder: (_) => SurveyScreen(userId: userId),
            );
          case 'Planner/DailyPlannerPage':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => DailyPlannerPage(
                userId: userId,
              ),
            );
          case 'Calendar/screens/calendar_screen':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => CalendarScreen(
                userId: userId,
              ),
            );
          case 'AI/ChatScreen':
            return MaterialPageRoute(
              settings: settings,
              builder: (context) {
                // ChatScreen에 필요한 데이터 및 콜백 준비
                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchUserData(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Text('데이터 로드 오류: ${snapshot.error}'),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    return ChatScreen(
                      userId: userId,
                      calendarData: data['calendarData'],
                      todoData: data['todoData'],
                      onEventAdded: (Map<String, dynamic> eventData) async {
                        print('일정 추가됨: ${eventData['title']}');
                        // 안전하게 pop 처리
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop({'refresh': true, 'returnToIndex': 1});
                        }
                      },
                      onEventDeleted: (String eventId) async {
                        print('일정 삭제됨: $eventId');
                        // 안전하게 pop 처리
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop({'refresh': true, 'returnToIndex': 1});
                        }
                      },
                    );
                  },
                );
              },
            );
          case 'Diary/screens/diary_screen':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => DiaryScreen(
                userId: userId,
              ),
            );
          case 'Setting/settings_page':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => SettingsPage(
                userId: userId,
              ),
            );
          default:
            return null;
        }
      },
    );
  }

  // 사용자 데이터 가져오는 함수
  Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    try {
      // 1. 캘린더 데이터 가져오기
      final calendarSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      final calendarData = calendarSnapshot.docs.map((doc) {
        final data = doc.data();

        // 날짜 데이터 형식 처리
        String dateStr = '';
        if (data['date'] is Timestamp) {
          dateStr = data['date'].toDate().toString().split(' ')[0];
        } else if (data['date'] is String) {
          dateStr = data['date'];
        } else if (data['startDate'] is Timestamp) {
          dateStr = data['startDate'].toDate().toString().split(' ')[0];
        } else if (data['startDate'] is String) {
          dateStr = data['startDate'];
        }

        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'date': dateStr,
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'location': data['location'] ?? '',
          'isCompleted': data['isCompleted'] ?? false,
        };
      }).toList();

      // 2. 할 일 데이터 가져오기
      final todoSnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: userId)
          .get();

      final todoData = todoSnapshot.docs.map((doc) {
        final data = doc.data();

        // 날짜 데이터 형식 처리
        String dateStr = '';
        if (data['date'] is Timestamp) {
          dateStr = data['date'].toDate().toString().split(' ')[0];
        } else if (data['date'] is String) {
          dateStr = data['date'];
        }

        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'date': dateStr,
          'time': data['time'] ?? '',
          'endTime': data['endTime'] ?? '',
          'importance': data['importance'] ?? 1,
          'urgency': data['urgency'] ?? 1,
          'isCompleted': data['isCompleted'] ?? false,
          'memo': data['memo'] ?? '',
          'location': data['location'] ?? '',
        };
      }).toList();

      return {
        'calendarData': calendarData,
        'todoData': todoData,
      };

    } catch (e) {
      print('사용자 데이터 가져오기 오류: $e');
      // 오류 발생 시에도 빈 데이터라도 반환
      return {
        'calendarData': <Map<String, dynamic>>[],
        'todoData': <Map<String, dynamic>>[],
      };
    }
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: 800), () {
      Navigator.pushReplacementNamed(context, 'Login/login_page');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE6E6FA),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text(
            'FocusMate',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Color(0xFF373775),
              letterSpacing: 1.5,
              fontFamily: 'NotoSansKR',
            ),
          ),
        ),
      ),
    );
  }
}