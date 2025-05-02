import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';

import 'Settings/settings_page.dart';

class BottomNav extends StatefulWidget {
  // 현재 화면에 따라 초기 인덱스를 설정하기 위한 생성자 추가
  final int initialIndex;
  final String userId; // 사용자 ID 추가

  const BottomNav({Key? key, this.initialIndex = 0, required this.userId}) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // 이미 선택된 탭이면 아무것도 하지 않음

    setState(() {
      _selectedIndex = index;
    });

    // 각 탭에 따라 다른 페이지로 이동
    switch (index) {
      case 0: // Calendar
        Navigator.pushReplacementNamed(
            context,
            'Calendar/screens/calendar_screen',
            // 빠른 페이지 전환을 위한 트랜지션 설정
            arguments: PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => DailyPlannerPage(),
              transitionDuration: Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            )
        );
        break;
      case 1: // Planner
        Navigator.pushReplacementNamed(
            context,
            'Planner/DailyPlannerPage',
            // 빠른 페이지 전환을 위한 트랜지션 설정
            arguments: PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => DailyPlannerPage(),
              transitionDuration: Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            )
        );
        break;
      case 2: // Diary
        Navigator.pushReplacementNamed(
            context,
            'Diary/main_diary',
            // 빠른 페이지 전환을 위한 트랜지션 설정
            arguments: PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => DailyPlannerPage(),
              transitionDuration: Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            )
        );
        break;
      case 3: // Community
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsPage(userId: widget.userId),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.grey.shade100,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF5E4DAE),
      unselectedItemColor: Colors.grey.shade400,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'Planner'
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Diary'
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'User'
        ),
      ],
    );
  }
}