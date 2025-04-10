import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';

void main() {
  testWidgets('AI 플래너 생성 후 자동 생성된 일정들이 화면에 표시되는지 테스트', (WidgetTester tester) async {
    // 플래너 화면을 렌더링
    await tester.pumpWidget(
      const MaterialApp(
        home: DailyPlannerPage(),
      ),
    );

    // 플래너 모드에서 + 버튼 탭
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(); // 다이얼로그 시작
    await tester.pump(const Duration(seconds: 3)); // AI 생성 대기시간

    // UI에 자동 생성된 일정이 화면에 표시되는지 확인
    expect(find.text('아침 운동'), findsOneWidget);
    expect(find.text('팀 미팅'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });
}
