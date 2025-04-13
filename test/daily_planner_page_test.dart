import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';

void main() {
  testWidgets('플래너 화면이 정상 렌더링되고 + 버튼이 존재해야 함', (WidgetTester tester) async {
    // 화면 렌더링
    await tester.pumpWidget(
      const MaterialApp(
        home: DailyPlannerPage(),
      ),
    );

    // + 버튼 존재 여부 확인
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('+ 버튼 클릭 시 다이얼로그가 나타나야 함 (플래너 모드)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DailyPlannerPage(),
      ),
    );

    // + 버튼 탭
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    //다이얼로그 기다리기
    await tester.pump(const Duration(milliseconds: 500)); // 다이얼로그 애니메이션 대기
    // 다이얼로그 안의 텍스트 확인
    expect(find.text('플래너 생성 중...'), findsOneWidget);

    //생성 완료 후 타이머도 끝나게 대기
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();//타이머 끝날 때까지 기다림
  });
}
