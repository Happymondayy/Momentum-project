import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';
import 'package:momentum_planner/Settings/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 전역 변수로 현재 선택된 인덱스 관리 (앱 전체에서 공유)
int globalSelectedIndex = 0;

class BottomNav extends StatefulWidget {
  final int initialIndex;
  final String userId;

  const BottomNav({Key? key, this.initialIndex = 0, required this.userId}) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  List<Map<String, dynamic>> _calendarData = [];
  List<Map<String, dynamic>> _todoData = [];

  @override
  void initState() {
    super.initState();
    // 초기화 시 전역 변수에 있는 값을 사용하되, initialIndex가 있으면 전역 변수를 업데이트
    if (widget.initialIndex != globalSelectedIndex) {
      globalSelectedIndex = widget.initialIndex;
    }
    print('BottomNav 초기화: userId = ${widget.userId}, initialIndex = $globalSelectedIndex');
  }

  void _onItemTapped(int index) {
    // 이미 선택된 탭을 다시 탭하면 아무것도 하지 않음
    if (globalSelectedIndex == index) return;

    // 전역 변수 업데이트
    setState(() {
      globalSelectedIndex = index;
    });

    // 현재 경로 저장 (뒤로가기 처리용)
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    print('현재 경로: $currentRoute, 선택된 탭: $index');

    switch (index) {
      case 0: // Calendar
        print('Calendar 탭으로 이동: userId = ${widget.userId}');
        if (currentRoute != 'Calendar/screens/calendar_screen') {
          Navigator.pushReplacementNamed(
            context,
            'Calendar/screens/calendar_screen',
            arguments: {'userId': widget.userId},
          );
        }
        break;

      case 1: // Planner
        print('📌 Planner 탭 클릭됨');
        print('📌 BottomNav userId: "${widget.userId}"');

        if (widget.userId.isEmpty) {
          print('❌ 오류: BottomNav에서 userId가 비어있음!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (currentRoute != 'Planner/DailyPlannerPage') {
          print('📌 DailyPlannerPage로 네비게이션 시작');

          // arguments도 함께 전달하도록 수정
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: RouteSettings(
                name: 'Planner/DailyPlannerPage',
                arguments: {'userId': widget.userId}, // arguments 추가
              ),
              builder: (context) {
                print('📌 DailyPlannerPage 빌더 호출 - userId: "${widget.userId}"');
                return DailyPlannerPage(
                  userId: widget.userId,
                  calendarData: _calendarData,
                );
              },
            ),
          );
        }
        break;

      case 2: // Diary
        print('Diary 탭으로 이동: userId = ${widget.userId}');
        if (currentRoute != 'Diary/screens/diary_screen') {
          Navigator.pushReplacementNamed(
            context,
            'Diary/screens/diary_screen',
            arguments: {'userId': widget.userId},
          );
        }
        break;

      case 3: // Settings
        print('Settings 탭으로 이동: userId = ${widget.userId}');
        if (currentRoute != 'Setting/settings_page' && widget.userId.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'Setting/settings_page'),
              builder: (context) => SettingsPage(userId: widget.userId),
            ),
          );
        } else if (widget.userId.isEmpty) {
          print('경고: userId가 비어 있습니다. Settings 페이지로 이동할 수 없습니다.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용자 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(0xFF9575CD),
      unselectedItemColor: Colors.grey.shade400,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: globalSelectedIndex, // 전역 변수 사용
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '캘린더',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.view_list),
          label: '플래너',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          label: '일기',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '설정',
        ),
      ],
    );
  }
}