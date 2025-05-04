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
        );
        break;
      case 1: // Planner
        Navigator.pushReplacementNamed(
          context,
          'Planner/DailyPlannerPage',
        );
        break;
      case 2: // Diary
        Navigator.pushReplacementNamed(
          context,
          'Diary/main_diary',
        );
        break;
      case 3: // Settings
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
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey.shade400,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '',
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: ''
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: ''
        ),
      ],
    );
  }
}