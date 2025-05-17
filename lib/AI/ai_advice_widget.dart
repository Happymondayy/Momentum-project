
import 'package:flutter/material.dart';

class AIAdviceWidget extends StatelessWidget {
  final List<Map<String, dynamic>> calendarData;
  final List<Map<String, dynamic>> todoData;
  final String date;
  final VoidCallback onTap;

  const AIAdviceWidget({
    Key? key,
    required this.calendarData,
    required this.todoData,
    required this.date,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEDFA),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.assistant,
              color: Color(0xFF373775),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 비서',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF373775),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getAdvicePreview(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF373775),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getAdvicePreview() {
    if (todoData.isEmpty && calendarData.isEmpty) {
      return "오늘 일정과 할 일에 대해 조언을 받아보세요.";
    } else if (todoData.isNotEmpty && calendarData.isEmpty) {
      return "${todoData.length}개의 할 일이 있습니다. 효율적인 작업 방법을 알려드릴게요.";
    } else if (todoData.isEmpty && calendarData.isNotEmpty) {
      return "${calendarData.length}개의 일정이 있습니다. 일정 관리를 도와드릴게요.";
    } else {
      return "오늘의 ${calendarData.length}개 일정과 ${todoData.length}개 할 일에 대한 조언이 준비되어 있어요.";
    }
  }
}