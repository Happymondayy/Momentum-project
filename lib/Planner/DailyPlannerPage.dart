import 'package:flutter/material.dart';
import 'calendar_section.dart';
import 'progress_section.dart';
import 'task_list_section.dart';

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isSwitched = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CalendarSection(),
            ProgressSection(),
            _buildTodayPlannerHeader(),
            const Expanded(child: TaskListSection()),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTodayPlannerHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Today Planner',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Switch(
            value: isSwitched,
            onChanged: (value) {
              setState(() => isSwitched = value);
            },
            activeTrackColor: const Color(0xFFD7D0FF),
            activeColor: const Color(0xFF9D8CFF),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFF9D8CFF),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF9D8CFF),
      unselectedItemColor: Colors.grey.shade400,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.view_list), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''),
      ],
    );
  }
}
