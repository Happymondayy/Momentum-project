import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import 'package:momentum_planner/Planner/DailyPlannerPage.dart';

void main() {
  group('Todo_Task 모델 테스트', () {
    test('할 일 생성 시 필드 값이 정확해야 함', () {
      final task = Todo_Task(
        title: '코딩 연습',
        date: DateTime(2025, 4, 10),
        time: '10:00',
        isImportant: true,
        isUrgent: false,
        importance: 3,
        urgency: 2,
        memo: '테스트 작성',
        location: '집',
      );

      expect(task.title, '코딩 연습');
      expect(task.isCompleted, false);
      expect(task.importance, 3);
    });
  });

  group('TaskDataService 기능 테스트', () {
    final service = TaskDataService();
    final date = DateTime(2025, 4, 10);
    final task = Todo_Task(
      title: '과제 제출',
      date: date,
      time: '14:00',
      isImportant: true,
      isUrgent: true,
      importance: 3,
      urgency: 3,
    );

    test('할 일을 추가하면 해당 날짜에 저장되어야 함', () {
      service.addTask(task);

      final tasks = service.getTasksForDate(date);
      expect(tasks.length, greaterThanOrEqualTo(1));
      expect(tasks.any((t) => t.title == '과제 제출'), true);
    });

    test('진행률 계산이 정확해야 함', () {
      // 완료 처리 하나 추가
      final completedTask = Todo_Task(
        title: '완료된 할 일',
        date: date,
        isCompleted: true,
        isImportant: false,
        isUrgent: false,
        importance: 1,
        urgency: 1,
      );
      service.addTask(completedTask);

      final progress = service.calculateProgressForDate(date);
      expect(progress, greaterThan(0.0));
      expect(progress, lessThanOrEqualTo(100.0));
    });
  });
}
