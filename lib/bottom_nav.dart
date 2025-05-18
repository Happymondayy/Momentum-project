import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';
import 'package:momentum_planner/Settings/settings_page.dart';

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
    print('BottomNav 초기화: userId = ${widget.userId}, initialIndex = ${widget.initialIndex}');
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0: // Calendar
        print('Calendar 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacementNamed(
          context,
          'Calendar/screens/calendar_screen',
          arguments: {'userId': widget.userId},
        );
        break;

      case 1: // Planner
        print('Planner 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacementNamed(
          context,
          'Planner/DailyPlannerPage',
          arguments: {'userId': widget.userId},
        );
        break;

      case 2: // Diary
        print('Diary 탭으로 이동: userId = ${widget.userId}');
        Navigator.pushReplacementNamed(
          context,
          'Diary/screens/diary_screen',
          arguments: {'userId': widget.userId},
        );
        break;

      case 3: // Settings
        print('Settings 탭으로 이동: userId = ${widget.userId}');
        if (widget.userId.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(userId: widget.userId),
            ),
          );
        } else {
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
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '',
        ),
      ],
    );
  }
}