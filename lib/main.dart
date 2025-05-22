// main.dart
import 'package:flutter/material.dart';
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
import 'package:firebase_core/firebase_core.dart';
import 'Todolist/screens/notification_test_page.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:momentum_planner/Calendar/services/notification_service_calendar.dart';
import 'package:momentum_planner/Calendar/services/notification_service_todolist.dart';
import 'screens/api_test_screen.dart';  // 테스트용

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 알림 및 권한 초기화
 // await NotificationService().init();
  //await NotificationServiceCalendar().init(); // 캘린더 일정 미리 알림 설정
  //await NotificationServiceTodolist().init(); // 캘린더 투두 미리 알림 설정

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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusMate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansKR',
      ),
      debugShowCheckedModeBanner: false,
      //home: NotificationTestPage(),
      home: SplashScreen(), //메인
      //home: ApiTestScreen(), //스케쥴러 연결 테스트용
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

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
              builder: (_) => SurveyScreen(userId: args?['userId'] ?? ''),
            );
          case 'Planner/DailyPlannerPage':
            return MaterialPageRoute(
              builder: (_) => DailyPlannerPage(userId: args?['userId'] ?? ''),
            );
          case 'Calendar/screens/calendar_screen':
            return MaterialPageRoute(
              builder: (_) => CalendarScreen(userId: args?['userId'] ?? ''),
            );
          case 'Diary/screens/diary_screen':
            return MaterialPageRoute(
              builder: (_) => DiaryScreen(userId: args?['userId'] ?? ''),
            );
          case 'Setting/settings_page':
            return MaterialPageRoute(
              builder: (_) => SettingsPage(userId: args?['userId'] ?? ''),
            );
          default:
            return null;
        }
      },
    );
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
