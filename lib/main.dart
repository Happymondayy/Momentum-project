import 'package:flutter/material.dart';
import 'package:momentum_planner/Calendar/screens/calendar_screen.dart';
import 'Login/login_page.dart'; // LoginPage를 import
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // Firebase 설정 파일 import
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase가 이미 초기화되지 않았다면 초기화
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform, // 명시적으로 options 추가
      );
      print("🔥 Firebase 초기화 성공!");
    } else {
      print("⚡ Firebase가 이미 초기화되었습니다.");
    }
  } catch (e) {
    print("❌ Firebase 초기화 실패: $e");
  }

  /*runApp(MyApp());*/
  runApp(SurveyApp());
}

/*
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusMate', // 앱 제목
      theme: ThemeData(
        primarySwatch: Colors.blue, // 기본 테마 색상
        fontFamily: 'NotoSansKR', // 폰트 설정
      ),
      home: DailyPlannerPage(), // 앱 시작 시 보일 첫 번째 화면 (LoginPage)
      debugShowCheckedModeBanner: false, // 디버그 배너 숨기기
    );
  }
}*/

class SurveyApp extends StatelessWidget {
  const SurveyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: CalendarScreen(),
    );
  }
}
