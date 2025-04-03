import 'package:flutter/material.dart';
import 'dart:math';

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // SingleChildScrollView로 감싸서 스크롤 가능하게 함
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's tasks section
            _buildTodoSectionHeader('My Today Tasks'),
            _buildTodoList(context, todayTasks: true),

            const SizedBox(height: 20),

            // Yesterday's tasks section
            _buildTodoSectionHeader('My Yesterday Tasks'),
            _buildTodoList(context, todayTasks: false),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTodoList(BuildContext context, {required bool todayTasks}) {
    // Sample data - replace with your actual data source
    final List<Map<String, dynamic>> tasks = todayTasks
        ? [
      {'title': 'Running', 'description': 'Today is the marathon - check it out'},
      {'title': 'Lunch', 'description': 'Today is the reunion - check it out'},
      {'title': 'Study', 'description': 'Math - pg 10-152', 'time': 'AM 11:30 - PM 13:50'},
    ]
        : [
      {'title': 'Home', 'description': 'Today is the marathon - check it out'},
      {'title': 'Language study', 'description': 'Today is the marathon - check it out'},
    ];

    return Column(
      children: tasks.map((task) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                // 랜덤 파스텔 색상 생성
                color: getBrightPastelColor(),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Text(
              task['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['description'],
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                if (task.containsKey('time')) ...[
                  const SizedBox(height: 4),
                  Text(
                    task['time'],
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            isThreeLine: task.containsKey('time'),
          ),
        );
      }).toList(),
    );
  }

  // 밝은 파스텔 색상을 생성하는 메서드
  Color getBrightPastelColor() {
    final Random random = Random();

    // 미리 정의된 밝은 파스텔 색상 목록
    final List<Color> brightPastelColors = [
      const Color(0xFFFFE6E6), // 밝은 분홍색
      const Color(0xFFFFEDCC), // 밝은 복숭아색
      const Color(0xFFFFFFCC), // 밝은 노란색
      const Color(0xFFE6FFCC), // 밝은 연두색
      const Color(0xFFCCFFE1), // 밝은 민트색
      const Color(0xFFCCFFFF), // 밝은 하늘색
      const Color(0xFFCCE6FF), // 밝은 파란색
      const Color(0xFFE6CCFF), // 밝은 라벤더색
      const Color(0xFFFDD5DF), // 밝은 핑크색
      const Color(0xFFFFDAB9), // 밝은 살구색
      const Color(0xFFE0F7FA), // 밝은 청록색
      const Color(0xFFF1F8E9), // 밝은 라임색
      const Color(0xFFFCE4EC), // 밝은 로즈색
      const Color(0xFFF3E5F5), // 밝은 퍼플색
      const Color(0xFFE8F5E9), // 밝은 그린색
    ];

    // 랜덤하게 색상 선택
    return brightPastelColors[random.nextInt(brightPastelColors.length)];
  }
}