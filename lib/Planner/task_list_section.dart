import 'package:flutter/material.dart';
import 'dart:math';

class TaskListSection extends StatelessWidget {
  const TaskListSection({Key? key}) : super(key: key);

  // 파스텔 톤 색상 리스트를 const로 선언
  static const List<Color> pastelColors = [
    Color(0xFFB3E5FC), // 파스텔 블루
    Color(0xFFFFE6C2), // 파스텔 오렌지
    Color(0xFFDCFFD4), // 파스텔 그린
    Color(0xFFFFF9C4), // 파스텔 옐로우
    Color(0xFFF2E7F7), // 파스텔 퍼플
    Color(0xFFD4FCFF), // 파스텔 옐로우 그린
  ];

  // 랜덤으로 색상 선택
  Color getRandomPastelColor() {
    final random = Random();
    return pastelColors[random.nextInt(pastelColors.length)];
  }

  // 시간 포맷 생성
  String getTimeString() {
    final now = DateTime.now();
    return "${now.hour}:${now.minute < 10 ? '0${now.minute}' : now.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white, // 큰 네모 박스 배경 색상 (흰색)
        child: ListView.builder(
          itemCount: 10, // 예제 데이터 (나중에 실제 데이터로 변경 가능)
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽에 시간 표시
                  Text(
                    getTimeString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16), // 시간과 일정 박스 사이의 간격

                  // 일정 박스
                  Expanded(
                    child: Card(
                      color: getRandomPastelColor(), // 랜덤한 파스텔 색상으로 설정
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 일정 제목
                            Text(
                              'Task ${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 세부 일정 내용
                            const Text(
                              '세부 일정 내용',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0484444),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 오른쪽에 삭제 버튼
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  // 삭제 기능 구현 예정
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
