import 'package:flutter/material.dart';
import 'package:momentum_planner/Calendar/screens/calendar_screen.dart';
import 'package:momentum_planner/Diary/screens/diary_screen.dart';
import 'package:momentum_planner/Login/find_ID_page.dart';
import 'package:momentum_planner/Login/find_password_page.dart';
import 'package:momentum_planner/Login/signup_page.dart';
import 'Login/login_page.dart'; // LoginPage를 import
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';
import 'package:momentum_planner/Settings/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      initialRoute: 'Login/login_page',
      // ✅ arguments 사용을 위해 routes 대신 onGenerateRoute 사용
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
