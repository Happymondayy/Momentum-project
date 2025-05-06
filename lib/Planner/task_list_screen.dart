import 'package:flutter/material.dart';
import 'dart:math';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  // 파스텔 톤 색상 리스트를 const로 선언
  static const List<Color> pastelColors = [
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