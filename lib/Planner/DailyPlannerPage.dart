import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import '../AI/chat_screen.dart';
import '../main.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:momentum_planner/Todolist/screens/notification_service.dart';


// API URL (Flask 서버 URL)
final String apiUrl = 'http://localhost:5000';  // 로컬 개발 환경에서 사용할 경우

// TaskDataService 클래스
class TaskDataService {
  static final TaskDataService _instance = TaskDataService._internal();

  factory TaskDataService() {
    return _instance;
  }

  TaskDataService._internal();

  // Firestore 컬렉션 참조
  final CollectionReference todoCollection = FirebaseFirestore.instance
      .collection('todos');
  final CollectionReference plannerCollection = FirebaseFirestore.instance
      .collection('planners');

// 사용자 ID 저장 변수
  String? currentUserId;

// 사용자 ID 설정 메서드
  void setUserId(String userId) {
    currentUserId = userId;
  }


  List<Todo_Task> _generateRepeatTodos(Todo_Task baseTodo, Map<String, dynamic> data) {
    List<Todo_Task> repeatTodos = [];
    final repeatOption = data['repeatOption'];
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 365));

    DateTime currentDate = baseTodo.date.add(Duration(days: 1));

    while (currentDate.isBefore(endDate)) {
      bool shouldAdd = false;

      switch (repeatOption) {
        case '매일':
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case '매주':
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: 7));
          break;
        case '매달':
          shouldAdd = true;
          currentDate = DateTime(
              currentDate.year, currentDate.month + 1, baseTodo.date.day);
          break;
        case '매년':
          shouldAdd = true;
          currentDate = DateTime(
              currentDate.year + 1, baseTodo.date.month, baseTodo.date.day);
          break;
        case '매요일':
        // 수정된 부분: 안전하게 repeatDays 처리
          final repeatDays = _parseRepeatDays(data['repeatDays']) ?? <int>[];
          if (repeatDays.contains(currentDate.weekday - 1)) {
            shouldAdd = true;
          }
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case '기타':
          final customDays = data['repeatCustomDays'] ?? 1;
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: customDays));
          break;
        default:
          currentDate = currentDate.add(Duration(days: 1));
      }

      if (shouldAdd) {
        final repeatTodo = Todo_Task(
          id: '${baseTodo.id}_${currentDate.millisecondsSinceEpoch}',
          userId: baseTodo.userId,
          title: baseTodo.title,
          description: baseTodo.description,
          time: baseTodo.time,
          endTime: baseTodo.endTime,
          date: currentDate,
          isImportant: baseTodo.isImportant,
          isUrgent: baseTodo.isUrgent,
          memo: baseTodo.memo,
          location: baseTodo.location,
          importance: baseTodo.importance,
          urgency: baseTodo.urgency,
          isCompleted: false,
          color: baseTodo.color,
          dueDate: baseTodo.dueDate,
          notificationId: null,
          reminderMinutesBefore: baseTodo.reminderMinutesBefore,
          isRepeating: baseTodo.isRepeating,
          repeatOption: baseTodo.repeatOption,
          repeatDays: baseTodo.repeatDays,
          repeatCustomDays: baseTodo.repeatCustomDays,
        );
        repeatTodos.add(repeatTodo);
      }
    }

    return repeatTodos;
  }

  List<int>? _parseRepeatDays(dynamic repeatDaysData) {
    if (repeatDaysData == null) return null;

    try {
      if (repeatDaysData is List) {
        // List인 경우 각 요소를 안전하게 int로 변환
        return repeatDaysData.map((e) {
          if (e is int) return e;
          if (e is String) {
            final parsed = int.tryParse(e);
            if (parsed != null) return parsed;
          }
          return 0; // 기본값
        }).where((e) => e >= 0 && e <= 6).toList(); // 유효한 요일만 필터링
      } else if (repeatDaysData is String) {
        // String인 경우 파싱
        String cleanString = repeatDaysData.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');
        if (cleanString.isEmpty) return null;

        return cleanString
            .split(',')
            .map((s) {
          final parsed = int.tryParse(s.trim());
          return parsed ?? 0;
        })
            .where((e) => e >= 0 && e <= 6) // 유효한 요일만 필터링
            .toList();
      }
    } catch (e) {
      print('repeatDays 파싱 오류: $e, 데이터: $repeatDaysData');
    }

    return null;
  }

  DateTime _getNextRepeatDate(DateTime currentDate, String? repeatOption, Map<String, dynamic> data) {
    switch (repeatOption) {
      case '매일':
        return currentDate.add(Duration(days: 1));

      case '매주':
        return currentDate.add(Duration(days: 7));

      case '매달':
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int targetDay = currentDate.day;
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay);

      case '매년':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);

      case '매요일':
      // 수정된 부분: 안전하게 repeatDays 처리
        final repeatDays = _parseRepeatDays(data['repeatDays']) ?? <int>[];
        if (repeatDays.isEmpty) return currentDate.add(Duration(days: 1));

        DateTime nextDate = currentDate.add(Duration(days: 1));
        while (!repeatDays.contains(nextDate.weekday - 1)) {
          nextDate = nextDate.add(Duration(days: 1));
        }
        return nextDate;

      case '기타':
        final customDays = data['repeatCustomDays'] ?? 1;
        return currentDate.add(Duration(days: customDays));

      default:
        return currentDate.add(Duration(days: 1));
    }
  }

  Todo_Task _createTodoTaskFromData(Map<String, dynamic> data, String docId, DateTime dateTime) {
    // repeatDays 안전하게 파싱
    List<int>? safeRepeatDays;
    try {
      safeRepeatDays = _parseRepeatDays(data['repeatDays']);
    } catch (e) {
      print('repeatDays 파싱 실패: $e');
      safeRepeatDays = null;
    }

    return Todo_Task(
      id: docId,
      userId: data['userId'] ?? currentUserId ?? '',
      title: data['title'] ?? '',
      description: data['description']?.toString(),
      time: data['time']?.toString(),
      endTime: data['endTime']?.toString(),
      date: dateTime,
      isImportant: data['isImportant'] ?? false,
      isUrgent: data['isUrgent'] ?? false,
      memo: data['memo']?.toString(),
      location: data['location']?.toString(),
      importance: data['importance'] ?? 1,
      urgency: data['urgency'] ?? 1,
      isCompleted: data['isCompleted'] ?? false,
      dueDate: data['dueDate']?.toString() != null
          ? DateTime.tryParse(data['dueDate']) ?? null
          : null,
      isRepeating: data['isRepeating'] ?? false,
      repeatOption: data['repeatOption']?.toString(),
      repeatDays: safeRepeatDays, // 안전하게 파싱된 데이터 사용
      repeatCustomDays: data['repeatCustomDays'],
    );
  }



  void _addTodoTaskToDateMap(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }

    // 중복 체크: 동일한 제목과 날짜의 태스크가 있는지 확인
    bool isDuplicate = todoTasksByDate[dateKey]!.any((t) =>
    t.title == task.title &&
        _isSameDay(t.date, task.date));

    if (!isDuplicate) {
      todoTasksByDate[dateKey]!.add(task);
    }
  }

  void _addPlannerTaskToDateMap(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey] = [];
    }

    // 중복 체크
    bool isDuplicate = plannerTasksByDate[dateKey]!.any((t) =>
    t.title == task.title &&
        _isSameDay(t.date, task.date));

    if (!isDuplicate) {
      plannerTasksByDate[dateKey]!.add(task);
    }
  }

  // TaskDataService 클래스 내부에 추가할 함수

// 태스크 기반 다음 반복 날짜 계산 함수
  DateTime _getNextRepeatDateForTask(DateTime currentDate, Todo_Task task) {
    switch (task.repeatOption) {
      case '매일':
        return currentDate.add(Duration(days: 1));

      case '매주':
        return currentDate.add(Duration(days: 7));

      case '매달':
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int targetDay = currentDate.day;
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay);

      case '매년':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);

      case '매요일':
        if (task.repeatDays == null || task.repeatDays!.isEmpty) {
          return currentDate.add(Duration(days: 1));
        }

        // 다음 해당 요일 찾기
        DateTime nextDate = currentDate.add(Duration(days: 1));
        int searchLimit = 0;
        while (!task.repeatDays!.contains(nextDate.weekday - 1) && searchLimit < 7) {
          nextDate = nextDate.add(Duration(days: 1));
          searchLimit++;
        }
        return nextDate;

      case '기타':
        final customDays = task.repeatCustomDays ?? 1;
        return currentDate.add(Duration(days: customDays));

      default:
        return currentDate.add(Duration(days: 1));
    }
  }

// 날짜 비교 헬퍼 함수
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Todo Task를 Firestore에 저장 (반복 필드 추가)
  Future<void> saveTodoTaskToFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      await todoCollection.add({
        'userId': currentUserId,
        'title': task.title,
        'description': task.description,
        'time': task.time,
        'endTime': task.endTime,
        'date': task.date.toIso8601String(),
        'isImportant': task.isImportant,
        'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating, // 반복 필드 추가
        'repeatOption': task.repeatOption,
        'repeatDays': task.repeatDays,
        'repeatCustomDays': task.repeatCustomDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Todo Task 저장 오류: $e');
    }
  }

// Planner Task를 Firestore에 저장 (반복 필드 추가)
  Future<void> savePlannerTaskToFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      await plannerCollection.add({
        'userId': currentUserId,
        'title': task.title,
        'description': task.description,
        'time': task.time,
        'endTime': task.endTime,
        'date': task.date.toIso8601String(),
        'isImportant': task.isImportant,
        'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating, // 반복 필드 추가
        'repeatOption': task.repeatOption,
        'repeatDays': task.repeatDays,
        'repeatCustomDays': task.repeatCustomDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Planner Task 저장 오류: $e');
    }
  }

// Task 상태 업데이트 (완료/미완료)
  Future<void> updateTaskCompletionInFirestore(Todo_Task task,
      bool isCompleted) async {
    if (currentUserId == null) return;

    try {
      // Todo 컬렉션 확인
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.update({'isCompleted': isCompleted});
      }

      // Planner 컬렉션 확인
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in plannerQuery.docs) {
        await doc.reference.update({'isCompleted': isCompleted});
      }
    } catch (e) {
      print('Task 상태 업데이트 오류: $e');
    }
  }


  // 특정 날짜의 Planner 작업 모두 삭제 (개선된 버전)
  Future<void> clearPlannerTasksForDate(DateTime date) async {
    if (currentUserId == null) return;

    final dateKey = dateToKey(date);

    try {
      // 1. 먼저 로컬 캐시 데이터 삭제
      plannerTasksByDate.remove(dateKey);

      // 2. Firestore에서 해당 날짜의 문서 검색
      final dateStr = date.toIso8601String().split('T')[0]; // 날짜만 추출 (시간 제외)

      // 해당 날짜에 대한 모든 플래너 문서 가져오기
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .get();

      // 3. 해당 날짜와 일치하는 문서만 필터링하여 삭제
      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasDocumentsToDelete = false;

      for (var doc in plannerQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['date'] != null) {
          final docDate = DateTime.parse(data['date']).toIso8601String().split(
              'T')[0];
          if (docDate == dateStr) {
            batch.delete(doc.reference);
            hasDocumentsToDelete = true;
          }
        }
      }

      // 삭제할 문서가 있을 경우에만 batch 커밋
      if (hasDocumentsToDelete) {
        await batch.commit();
      }

      print('Planner Tasks for $dateKey 삭제 완료');
    } catch (e) {
      print('Planner Tasks 삭제 오류: $e');
    }
  }

  // Todo List와 Planner 데이터를 분리하여 저장
  final Map<String, List<Todo_Task>> todoTasksByDate = {};
  final Map<String, List<Todo_Task>> plannerTasksByDate = {};

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String dateToKey(DateTime date) {
    date = _normalizeDate(date);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
        .toString().padLeft(2, '0')}';
  }

  // 날짜 비교 메서드
  bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Todo List 조회 메서드
  List<Todo_Task> getTodoTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return todoTasksByDate[dateKey]?.where((task) =>
        isSameDate(task.date, date)).toList() ?? [];
  }

  // TaskDataService의 addTodoTask 메서드 수정
  void addTodoTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }

    // 기본 태스크 추가
    if (!todoTasksByDate[dateKey]!.any((existingTask) =>
    _isSameDay(existingTask.date, task.date) &&
        existingTask.title == task.title)) {
      todoTasksByDate[dateKey]!.add(task);
      // Firestore에 저장
      saveTodoTaskToFirestore(task);

      // 반복 설정이 있으면 반복 투두들도 생성
      if (task.isRepeating && task.repeatOption != null) {
        _generateAndAddRepeatTodos(task);
      }
    }
  }

  // 개선된 반복 투두 생성 및 추가 함수
  void _generateAndAddRepeatTodos(Todo_Task baseTask) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 365)); // 1년간 반복 생성
    DateTime currentDate = baseTask.date;

    // 최대 100개까지만 생성 (무한 반복 방지)
    int generatedCount = 0;
    const int maxRepeatTasks = 100;

    while (currentDate.isBefore(endDate) && generatedCount < maxRepeatTasks) {
      DateTime nextDate = _getNextRepeatDateForTask(currentDate, baseTask);

      if (nextDate.isAfter(endDate)) break;

      // 원본 날짜가 아닌 경우에만 반복 태스크 생성
      if (!_isSameDay(nextDate, baseTask.date)) {
        final repeatTask = baseTask.copyWith(
          id: '${baseTask.id}_repeat_${nextDate.millisecondsSinceEpoch}',
          date: nextDate,
          isCompleted: false, // 반복 일정은 항상 미완료로 시작
          notificationId: null, // 새로운 알림 ID 필요
        );

        // 로컬 메모리에 추가
        final dateKey = dateToKey(nextDate);
        if (!todoTasksByDate.containsKey(dateKey)) {
          todoTasksByDate[dateKey] = [];
        }

        // 중복 체크 후 추가
        bool isDuplicate = todoTasksByDate[dateKey]!.any((t) =>
        t.title == repeatTask.title &&
            _isSameDay(t.date, repeatTask.date));

        if (!isDuplicate) {
          todoTasksByDate[dateKey]!.add(repeatTask);
          // Firestore에도 저장
          saveTodoTaskToFirestore(repeatTask);
          generatedCount++;
        }
      }

      currentDate = nextDate;
    }
  }

  DateTime getNextRepeatDate(DateTime currentDate, String? repeatOption, Map<String, dynamic> data) {
    switch (repeatOption) {
      case '매일':
        return currentDate.add(Duration(days: 1));

      case '매주':
        return currentDate.add(Duration(days: 7));

      case '매달':
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int targetDay = currentDate.day;
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay);

      case '매년':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);

      case '매요일':
      // 수정된 부분: 안전하게 repeatDays 처리
        final repeatDays = _parseRepeatDays(data['repeatDays']) ?? <int>[];
        if (repeatDays.isEmpty) return currentDate.add(Duration(days: 1));

        DateTime nextDate = currentDate.add(Duration(days: 1));
        while (!repeatDays.contains(nextDate.weekday - 1)) {
          nextDate = nextDate.add(Duration(days: 1));
        }
        return nextDate;

      case '기타':
        final customDays = data['repeatCustomDays'] ?? 1;
        return currentDate.add(Duration(days: customDays));

      default:
        return currentDate.add(Duration(days: 1));
    }
  }

  // Firestore에서 반복 일정도 제대로 로드하도록 수정
  Future<void> loadTasksFromFirestore(String userId) async {
    setUserId(userId);

    // 데이터를 로드하기 전에 기존 데이터 초기화
    todoTasksByDate.clear();
    plannerTasksByDate.clear();

    // Todo 데이터 로드
    try {
      final todoSnapshot = await todoCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in todoSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTime = DateTime.parse(data['date']);

        // 모든 투두 태스크 생성 (반복 여부 상관없이)
        final task = _createTodoTaskFromData(data, doc.id, dateTime);
        _addTodoTaskToDateMap(task);
      }

      // Planner 데이터 로드
      final plannerSnapshot = await plannerCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in plannerSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTime = DateTime.parse(data['date']);

        final task = _createTodoTaskFromData(data, doc.id, dateTime);
        _addPlannerTaskToDateMap(task);
      }

      print('Firestore 데이터 로드 완료: Todo ${todoTasksByDate
          .length}, Planner ${plannerTasksByDate.length}');
    } catch (e) {
      print('Firestore 데이터 로드 오류: $e');
    }
  }

  // Planner용 메서드
  List<Todo_Task> getPlannerTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return plannerTasksByDate[dateKey] ?? [];
  }

  void addPlannerTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.add(task);
    } else {
      plannerTasksByDate[dateKey] = [task];
    }

    // Firestore에 저장
    savePlannerTaskToFirestore(task);
  }

  // Firestore에서 Task 삭제하는 함수
  Future<void> removeTaskFromFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      // Todo 컬렉션 확인
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      // Todo 데이터 삭제
      for (var doc in todoQuery.docs) {
        await doc.reference.delete();
      }

      // Planner 컬렉션 확인
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      // Planner 데이터 삭제
      for (var doc in plannerQuery.docs) {
        await doc.reference.delete();
      }

      print('${task.title} 삭제 완료');
    } catch (e) {
      print('Task 삭제 오류: $e');
    }
  }

// 기존 removeTask 함수 수정
  Future<void> removeTask(Todo_Task task) async {
    // 로컬 데이터 삭제
    final dateKey = dateToKey(task.date);
    if (todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }

    // Firestore에서도 삭제
    await removeTaskFromFirestore(task);
  }

  // 진행률 계산
  double calculateCombinedProgressForDate(DateTime date) {
    final todoTasks = getTodoTasksForDate(date);
    final plannerTasks = getPlannerTasksForDate(date);
    final totalTasks = todoTasks.length + plannerTasks.length;
    if (totalTasks == 0) return 0.0;
    final completedTasks = todoTasks
        .where((task) => task.isCompleted)
        .length +
        plannerTasks
            .where((task) => task.isCompleted)
            .length;
    return (completedTasks / totalTasks) * 100;
  }

  Future<void> updateTaskInFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      // Todo 컬렉션에서 업데이트
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.update({
          'title': task.title,
          'description': task.description,
          'time': task.time,
          'endTime': task.endTime,
          'date': task.date.toIso8601String(),
          'isImportant': task.isImportant,
          'isUrgent': task.isUrgent,
          'memo': task.memo,
          'location': task.location,
          'importance': task.importance,
          'urgency': task.urgency,
          'isCompleted': task.isCompleted,
          'dueDate': task.dueDate?.toIso8601String(),
          'isRepeating': task.isRepeating,
          'repeatOption': task.repeatOption,
          'repeatDays': task.repeatDays,
          'repeatCustomDays': task.repeatCustomDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Planner 컬렉션에서도 업데이트
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in plannerQuery.docs) {
        await doc.reference.update({
          'title': task.title,
          'description': task.description,
          'time': task.time,
          'endTime': task.endTime,
          'date': task.date.toIso8601String(),
          'isImportant': task.isImportant,
          'isUrgent': task.isUrgent,
          'memo': task.memo,
          'location': task.location,
          'importance': task.importance,
          'urgency': task.urgency,
          'isCompleted': task.isCompleted,
          'dueDate': task.dueDate?.toIso8601String(),
          'isRepeating': task.isRepeating,
          'repeatOption': task.repeatOption,
          'repeatDays': task.repeatDays,
          'repeatCustomDays': task.repeatCustomDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('Task 업데이트 완료: ${task.title}');
    } catch (e) {
      print('Task 업데이트 오류: $e');
    }
  }



  // Task 상태 업데이트 함수 개선
  void updateTaskStatus(Todo_Task task, bool isCompleted) {
    final dateKey = dateToKey(task.date);

    // 로컬 데이터 업데이트
    if (todoTasksByDate.containsKey(dateKey)) {
      try {
        final todoTask = todoTasksByDate[dateKey]!
            .firstWhere((t) =>
        t.title == task.title && _isSameDay(t.date, task.date));
        todoTask.isCompleted = isCompleted;
      } catch (e) {}
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      try {
        final plannerTask = plannerTasksByDate[dateKey]!
            .firstWhere((t) =>
        t.title == task.title && _isSameDay(t.date, task.date));
        plannerTask.isCompleted = isCompleted;
      } catch (e) {}
    }

    // 태스크 자체 업데이트
    task.isCompleted = isCompleted;

    // Firestore 업데이트
    this.updateTaskCompletionInFirestore(task, isCompleted);
  }
}


class DailyPlannerPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>>? calendarData; // calendarData를 선택적으로 추가

  const DailyPlannerPage({
    Key? key,
    required this.userId,
    this.calendarData, // 선택적 매개변수로 정의
  }) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}



class _DailyPlannerPageState extends State<DailyPlannerPage> {
  late String userId; // 나중에 초기화할 변수
  final NotificationService _notificationService = NotificationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    userId = args?['userId'] ?? '';
    print('📌 userId 받은 값: $userId');
  }

  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> calendarEvents = [];
  bool isLoading = false;
  TodoListScreenState? todoListScreenState;
  final TaskDataService _taskDataService = TaskDataService();
  double progressPercentage = 0.0;


  @override
  void initState() {
    super.initState();
    userId = widget.userId; // 여기서 초기화
    print('📌 userId 받은 값: $userId');

    // 파이어스토어에서 데이터 로드
    _taskDataService.setUserId(userId);
    _loadData();
  }

// 파이어스토어에서 데이터 로드하는 메서드 수정
  Future<void> _loadData() async {
    await _taskDataService.loadTasksFromFirestore(userId);
    updateProgress();
  }

  void updateProgress() {
    setState(() {
      progressPercentage =
          _taskDataService.calculateCombinedProgressForDate(selectedDate);
    });
  }


  // 5763820

  final TextEditingController _inputController = TextEditingController();
  String _algorithmOutput = '';
  String _geminiOutput = '';
  bool _isLoading = false;
  String _errorMessage = '';

  // Flask 서버 URL (실제 서버 주소로 변경 필요)
  final String serverUrl_1 = 'https://railwavve-production-68d4.up.railway.app/schedule_';  // 에뮬레이터 사용 시
  final String serverUrl__ = 'https://railwavve-production-68d4.up.railway.app/schedule_';  // 웹에서 테스트 시
  // final String serverUrl = 'http://your-server-ip:5000/schedule_';  // 실제 서버 IP로 접속 시

  Future<void> _getSchedule() async {

    int _calculateDuration(String? start, String? end) {
      if (start == null || end == null) return 1;

      try {
        final startParts = start.split(':').map(int.parse).toList();
        final endParts = end.split(':').map(int.parse).toList();

        final startMinutes = startParts[0] * 60 + startParts[1];
        final endMinutes = endParts[0] * 60 + endParts[1];

        final duration = ((endMinutes - startMinutes) / 60).round();
        return duration > 0 ? duration : 1;
      } catch (e) {
        return 1;
      }
    }


    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final List<Todo_Task> todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
    final List<String> formattedList = todoTasks.map((task) {
      final name = task.title;
      final importance = task.importance ?? 1;
      final urgency = task.urgency ?? 1;
      final duration = _calculateDuration(task.time, task.endTime);
      final startTime = task.time ?? '0';
      final endTime = task.endTime ?? '0';

      return '(N: $name, I: $importance, U: $urgency, D: $duration, T: $startTime, T: $endTime)';
    }).toList(); // 여기서는 join하지 않고 리스트 상태로 유지

// 유저 선호도 정리
    Map<String, dynamic> userPreferences = await _getUserPreferences();

// 🔹 1. 수면 종료 시간 파싱 (S)
    String sleepSchedule = userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00';
    int sleepEndHour = 7; // 기본값

    try {
      final sleepEndStr = sleepSchedule.split('~').last.trim();
      final parts = sleepEndStr.split(' ');
      final ampm = parts[0];
      final hourMinute = parts[1];
      int hour = int.parse(hourMinute.split(':')[0]);

      if (ampm == 'PM' && hour != 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      sleepEndHour = hour;
    } catch (e) {
      print('수면 종료 시간 파싱 실패: $e');
    }

// 🔹 2. 휴식 시간 파싱 (H)
    String breakFrequency = userPreferences['breakFrequency'] ?? '1시간마다';
    int breakHour = 1; // 기본값

    try {
      final hourMatch = RegExp(r'\d+').firstMatch(breakFrequency);
      if (hourMatch != null) {
        int value = int.parse(hourMatch.group(0)!);

        if (breakFrequency.contains('분')) {
          breakHour = (value / 60).ceil();
        } else {
          breakHour = value;
        }
      }
    } catch (e) {
      print('휴식 시간 파싱 실패: $e');
    }

// 🔹 최종 문자열로 조합
    String result = '[S: $sleepEndHour, H: $breakHour]';

// 한 줄로 모든 정보 출력하기
    String fullOutput = '$result${formattedList.join('')}';
// 또는 진짜 한 줄로 하고 싶다면:
// String fullOutput = '$result ${formattedList.join(' ')}';

    print(fullOutput);




    print("실행이 됩니까 실행이 됩니다");

    try {
      // HTTP POST 요청 보내기
      final response = await http.post(
        Uri.parse(serverUrl_1),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'input_text': fullOutput}),
      );

      if (response.statusCode == 200) {
        // 성공적으로 응답 받음
        final data = json.decode(response.body);

        setState(() {
          _algorithmOutput = data['algorithm_output'] ?? '결과 없음';
          _geminiOutput = data['gemini_output'] ?? '결과 없음';
          _isLoading = false;

          print("연결됨"+_algorithmOutput);
          print("연결됨"+_geminiOutput);
        });
      } else {
        // 오류 응답 처리
        setState(() {
          _errorMessage = '서버 오류: ${response.statusCode}';
          _isLoading = false;
          print("엥"+ _errorMessage);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '연결 오류: $e';
        _isLoading = false;
        print("엥"+ _errorMessage);
      });
    }
  }

  // 5763820




  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Calendar (Month selector)
            ImprovedMonthSelector(
              selectedDate: selectedDate,
              onMonthChanged: (newDate) {
                setState(() {
                  selectedDate = newDate;
                  updateProgress();
                });
              },
            ),
            // Weekly Calendar with horizontal scrolling
            EnhancedWeeklyCalendar(
              selectedDate: selectedDate,
              onDateSelected: changeSelectedDate,
            ),
            // Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProgressScreen(
                tasks: isPlannerView
                    ? _taskDataService.getPlannerTasksForDate(selectedDate)
                    : _taskDataService.getTodoTasksForDate(selectedDate),
                progressPercentage: progressPercentage,
              ),
            ),
            // Header with toggle
            _buildHeaderWithToggle(),
            Expanded(
              child: isPlannerView
                  ? (_taskDataService
                  .getPlannerTasksForDate(selectedDate)
                  .isEmpty
                  ? const EmptyStateWidget()
                  : _buildPlannerView())
                  : TodoListScreen(
                key: ValueKey(selectedDate),
                isEmbedded: true,
                initialDate: selectedDate,
                onStateCreated: (state) {
                  todoListScreenState = state;
                },
                onTaskStatusChanged: () {
                  updateProgress();
                },
                taskDataService: _taskDataService,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNav(
        initialIndex: 1,
        userId: widget.userId,
      ),
    );


  }

  Widget _buildHeaderWithToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isPlannerView
                ? (isSameDay(selectedDate, DateTime.now())
                ? 'My Today Planner'
                : 'Tasks for ${selectedDate.month}/${selectedDate.day}')
                : 'My Todo Task',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Switch(
            value: isPlannerView,
            onChanged: (value) {
              setState(() {
                isPlannerView = value;
                updateProgress();
              });
            },
            activeTrackColor: const Color(0xFFD7D0FF),
            activeColor: const Color(0xFF9D8CFF),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerView() {
    final tasks = _taskDataService.getPlannerTasksForDate(selectedDate);
    print('tasks length: ${tasks.length}');

    // 현재 날짜와 시간 정확히 가져오기
    final now = DateTime.now();
    final currentHour = now.hour;
    print('현재 시간: $currentHour시');

    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // 캘린더 및 투두리스트 정보 가져오기
    _fetchCalendarAndTodoCount();

    return SingleChildScrollView(
      child: Column(
        children: [
          // 상단 버튼 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 캘린더 및 투두리스트 개수 정보 표시
                Text(
                  '$_calendarCount Calendar and $_todoCount Task',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),

                // 일정 전체 삭제 버튼
                IconButton(
                  onPressed: () {
                    // 확인 대화상자 표시
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text('일정 초기화'),
                        content: const Text('이 날짜의 모든 일정을 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _taskDataService.clearPlannerTasksForDate(selectedDate);
                              setState(() {
                                updateProgress();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('삭제', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  tooltip: '모든 일정 삭제',
                ),
              ],
            ),
          ),

          // 시간별 일정 목록 - 전체 ListView로 변경
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 24,
            itemBuilder: (context, index) {
              final hour = index;
              final timeLabel = '${hour.toString().padLeft(2, '0')}:00';

              // 현재 시간에 해당하는지 확인
              final isCurrentHour = isToday && currentHour == hour;

              // 현재 시간대에 해당하는 일정들
              final hourTasks = tasks.where((task) {
                if (task.time == null || task.time!.isEmpty) return false;

                try {
                  // 24시간 형식 시간 (00:00)
                  if (task.time!.contains(':')) {
                    final parts = task.time!.split(':');
                    if (parts.length == 2) {
                      final taskHour = int.parse(parts[0]);
                      return taskHour == hour;
                    }
                  }

                  // AM/PM 형식 시간
                  if (task.time!.contains('AM') || task.time!.contains('PM')) {
                    final isPM = task.time!.contains('PM');
                    final timePart = task.time!.replaceAll('AM', '').replaceAll('PM', '').trim();
                    final timeParts = timePart.split(':');
                    if (timeParts.length == 2) {
                      int taskHour = int.parse(timeParts[0]);
                      if (isPM && taskHour < 12) taskHour += 12;
                      if (!isPM && taskHour == 12) taskHour = 0;
                      return taskHour == hour;
                    }
                  }
                } catch (e) {
                  print('시간 파싱 오류: $e');
                }

                return false;
              }).toList();

              // 전체 시간 행 - 시간 표시와 일정 영역을 함께 표시
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 시간 표시
                  Container(
                    width: 60,
                    height: hourTasks.isEmpty ? 70 : null,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      color: isCurrentHour
                          ? Colors.purple.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.03),
                    ),
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentHour
                            ? Colors.purple.shade600
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),

                  // 오른쪽 일정 영역
                  Expanded(
                    child: Container(
                      height: hourTasks.isEmpty ? 70 : null,
                      decoration: BoxDecoration(
                        color: isCurrentHour ? Colors.purple.withOpacity(0.05) : Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: isCurrentHour ? Colors.purple.shade400 : Colors.transparent,
                            width: isCurrentHour ? 3 : 0,
                          ),
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: hourTasks.isEmpty
                          ? Container() // 빈 시간대
                          : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: hourTasks.map((task) => _buildTodoTaskCard(task)).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

// 멤버 변수 추가
  int _calendarCount = 0;
  int _todoCount = 0;

  // 캘린더 이벤트와 투두 태스크 개수를 가져오는 메서드 (완전 재작성)
  void _fetchCalendarAndTodoCount() {
    // 투두 태스크 개수 계산
    final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
    _todoCount = todoTasks.length;

    // 선택된 날짜 확인용
    final selectedDateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    print('선택된 날짜: $selectedDateStr');

    // 임시 해결책: 하드코딩으로 캘린더 이벤트 수 설정
    setState(() {
      _calendarCount = 1; // 화면에 "1 Calendar"로 표시
    });

    // 디버깅용: 모든 이벤트 정보 출력
    FirebaseFirestore.instance
        .collection('events')
        .get()
        .then((snapshot) {
      print('==== 전체 이벤트 덤프 ====');
      print('총 이벤트 수: ${snapshot.docs.length}');



    })
        .catchError((error) {
      print('이벤트 조회 오류: $error');
    });
  }

// 날짜가 변경될 때 호출되는 메서드에 이벤트 개수 갱신 추가
  void changeSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      updateProgress();
      // 캘린더 및 투두 개수 다시 가져오기
      _fetchCalendarAndTodoCount();
    });
  }


// 사진과 비슷한 스타일의 TodoTask 카드 위젯
  Widget _buildTodoTaskCard(Todo_Task task) {
    final start = _parseTimeToDateTime(task.time);
    final end = _parseTimeToDateTime(task.endTime);
    final timeRange = (start != null && end != null)
        ? '${DateFormat.Hm().format(start)} - ${DateFormat.Hm().format(end)}'
        : '';

    // 완료 여부에 따른 스타일 조정
    final isCompleted = task.isCompleted;

    // 현재 날짜와 비교
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
    final diffDays = taskDate.difference(today).inDays;

    String dateStatus = '';
    if (diffDays == 0) {
      dateStatus = 'Today';
    } else if (diffDays == 1) {
      dateStatus = 'Tomorrow';
    } else if (diffDays == -1) {
      dateStatus = 'Yesterday';
    }

    // 제목에서 첫 글자만 대문자로 표시하기 위한 처리
    String taskInitial = task.title.isNotEmpty ? task.title[0].toUpperCase() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 부분 (제목 및 상태 표시)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작은 네모박스 (유지)
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      taskInitial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                // 날짜 및 시간 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 표시
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.grey : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 날짜 정보 표시
                      Text(
                        dateStatus.isNotEmpty
                            ? '$dateStatus, $timeRange'
                            : timeRange,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // 체크박스 (플레이 버튼 대신)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Checkbox(
                    value: task.isCompleted,
                    onChanged: (bool? value) {
                      setState(() {
                        _taskDataService.updateTaskStatus(task, value ?? false);
                        updateProgress();
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    activeColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // 하단 부분 (메모와 위치 정보)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 메모 정보 (파란색 세로선)
                if (task.memo != null && task.memo!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.blue.shade300,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      task.memo!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                // 위치 정보가 있으면 표시
                if (task.location != null && task.location!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          task.location!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 마감일이 있으면 표시 (참여자 아바타 그룹 제거)
                if (task.dueDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MM/dd').format(task.dueDate!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 시간 파싱 함수 수정
  DateTime? _parseTimeToDateTime(String? time) {
    if (time == null || time.isEmpty) return null;

    try {
      // 다양한 시간 형식 처리

      // 1. AM/PM 형식 (예: "PM 12:30")
      if (time.contains('AM') || time.contains('PM')) {
        final isPM = time.contains('PM');

        // 정규식으로 시간과 분 추출
        final regex = RegExp(r'(AM|PM)\s*(\d{1,2})(?::(\d{2}))?');
        final match = regex.firstMatch(time);

        if (match != null) {
          int hour = int.parse(match.group(2)!);
          int minute = 0;

          // 분이 있으면 파싱
          if (match.group(3) != null) {
            minute = int.parse(match.group(3)!);
          }

          // 12시간제 변환
          if (isPM && hour < 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;

          return DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              hour,
              minute
          );
        }
      }

      // 2. 24시간 형식 (예: "14:30")
      if (time.contains(':')) {
        final parts = time.split(':');
        if (parts.length == 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          return DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              hour,
              minute
          );
        }
      }
    } catch (e) {
      print('시간 파싱 오류: $e (입력: $time)');
    }

    return null;
  }

// _generateLocalSchedule 함수 수정 (캘린더 일정 제목에서 "(일정)" 제거)
  List<Map<String, dynamic>> _generateLocalSchedule(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar) {

    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 1. 캘린더 이벤트 먼저 추가 (고정 일정)
    for (var event in calendar) {
      if (event['startTime'] != null) {
        // 시간 정규화
        final normalizedStartTime = _normalizeTime(event['startTime']);
        final normalizedEndTime = _normalizeTime(event['endTime']);

        int startHour;
        try {
          startHour = int.parse(normalizedStartTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        int endHour;
        if (normalizedEndTime != null) {
          try {
            endHour = int.parse(normalizedEndTime.split(':')[0]);
            endHour = endHour.clamp(0, 23); // 범위 확인
          } catch (e) {
            endHour = startHour + 1; // 기본값
          }
        } else {
          endHour = startHour + 1;
        }

        // 시간이 뒤바뀐 경우 수정
        if (endHour < startHour) {
          endHour = startHour + 1;
        }

        // 시간대 차지 표시
        for (int h = startHour; h <= endHour; h++) {
          occupiedHours.add(h.clamp(0, 23));
        }

        schedule.add({
          'id': 'cal_${schedule.length}',
          'title': event['title'], // "(일정)" 접두사 제거
          'time': normalizedStartTime,
          'endTime': normalizedEndTime ?? '${(startHour + 1).toString().padLeft(2, '0')}:00',
          'priority': 3, // 최우선
          'description': '캘린더 일정',
          'memo': '',
          'location': event['location'] ?? '',
        });
      }
    }

    // 2. 작업 중요도/긴급도 기준 정렬
    tasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore); // 높은 점수가 먼저 오도록
    });

    // 3. 먼저 사용자가 지정한 시간이 있는 작업 추가
    for (var task in tasks) {
      // 사용자가 지정한 시간이 있는지 확인
      final userTime = task['time'];

      if (userTime != null && userTime.toString().isNotEmpty) {
        // 시간 정규화
        final normalizedTime = _normalizeTime(userTime.toString());
        final normalizedEndTime = _normalizeTime(task['endTime']?.toString());

        // 시작 시간의 시간대만 추출
        int startHour;
        try {
          startHour = int.parse(normalizedTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        // 종료 시간 설정
        String endTime;
        if (normalizedEndTime != null && normalizedEndTime.isNotEmpty) {
          endTime = normalizedEndTime;
        } else {
          // 기본 종료 시간은 시작 + 1시간
          endTime = '${((startHour + 1) % 24).toString().padLeft(2, '0')}:00';
        }

        // 시간대 차지 표시
        occupiedHours.add(startHour);

        // 중요도/긴급도에 따른 우선순위 설정
        final importance = task['importance'] ?? 1;
        final urgency = task['urgency'] ?? 1;
        final priority = importance > urgency ? importance : urgency;

        schedule.add({
          'id': 'task_${schedule.length}',
          'title': task['title'],
          'time': normalizedTime,
          'endTime': endTime,
          'priority': priority,
          'description': '중요도: $importance, 긴급도: $urgency',
          'memo': '',
          'location': '',
          'dueDate': task['dueDate'],
        });

        // 이미 처리된 작업은 표시
        task['_processed'] = true;
      }
    }

    // 4. 남은 시간대에 시간이 지정되지 않은 작업 배치
    int startHour = 9; // 오전 9시부터 시작

    for (var task in tasks) {
      // 이미 처리된 작업은 건너뛰기
      if (task['_processed'] == true) continue;

      // 하루 업무 시간 9시-21시로 제한
      if (startHour >= 21) break;

      // 사용 가능한 시간 찾기
      while (occupiedHours.contains(startHour)) {
        startHour++;
        if (startHour >= 21) break;
      }

      if (startHour >= 21) break;

      // 중요도/긴급도에 따른 우선순위 설정
      final importance = task['importance'] ?? 1;
      final urgency = task['urgency'] ?? 1;
      final priority = importance > urgency ? importance : urgency;

      schedule.add({
        'id': 'task_${schedule.length}',
        'title': task['title'],
        'time': '${startHour.toString().padLeft(2, '0')}:00',
        'endTime': '${(startHour + 1).toString().padLeft(2, '0')}:00',
        'priority': priority,
        'description': '중요도: $importance, 긴급도: $urgency',
        'memo': '',
        'location': '',
        'dueDate': task['dueDate'],
      });

      occupiedHours.add(startHour);
      startHour++;
    }

    // 시간순 정렬
    schedule.sort((a, b) {
      if (a['time'] == null) return 1;
      if (b['time'] == null) return -1;
      return a['time'].toString().compareTo(b['time'].toString());
    });

    return schedule;
  }



  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        if (isPlannerView) {
          _showPlannerGeneratingDialog();
        } else {
          if (todoListScreenState != null) {
            todoListScreenState!.showAddTaskDialog(context);
          }
        }
      },
      backgroundColor: const Color(0xFF9D8CFF),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  void _showPlannerGeneratingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D8CFF)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '플래너 생성 중...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '투두리스트와 캘린더 일정을 분석하여\n최적의 플래너를 생성하고 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // AI planner generation simulation
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop();
      _generateAIPlanner();
    });
  }

  String? _normalizeTime(String? time) {
    if (time == null) return null;

    // AM/PM 형식 처리
    bool isPM = false;
    if (time.contains('PM')) {
      isPM = true;
      time = time.replaceAll('PM', '').trim();
    } else if (time.contains('AM')) {
      time = time.replaceAll('AM', '').trim();
    }

    final parts = time.split(':');
    if (parts.length != 2) return time;

    // 시간 값 파싱 및 유효성 검사
    int hour;
    try {
      hour = int.parse(parts[0]);

      // AM/PM 형식인 경우 24시간제로 변환
      if (isPM && hour < 12) {
        hour += 12; // PM일 경우 12를 더함 (PM 12시는 예외)
      } else if (!isPM && hour == 12) {
        hour = 0; // AM 12시는 0시로 변환
      }

      // 시간 범위 유효성 검사: 0-23 범위로 제한
      hour = hour.clamp(0, 23);
    } catch (e) {
      hour = 9; // 기본값 설정
    }

    // 분 값 파싱 및 유효성 검사
    int minute;
    try {
      minute = int.parse(parts[1]);
      // 분 범위 유효성 검사: 0-59 범위로 제한
      minute = minute.clamp(0, 59);
    } catch (e) {
      minute = 0; // 기본값 설정
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }




  String convertTimeIfNeeded(dynamic timeValue) {
    if (timeValue == null) return '';

    String timeStr = timeValue.toString();

    // 이미 :가 있으면 그대로 반환
    if (timeStr.contains(':')) {
      return timeStr;
    }

    // :가 없으면 변환
    double time = double.tryParse(timeStr) ?? 0.0;
    int hours = time.floor();
    int minutes = ((time - hours) * 100).round();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _generateAIPlanner() async {
    // Show loading indicator while processing
    setState(() {
      isLoading = true; // Add this variable to your state
    });

    final List<Todo_Task> todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);

    // Firebase에서 Calendar Event 가져오기 (시간 포함)
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    List<Map<String, dynamic>> calendarEvents = [];

    for (var doc in eventsSnapshot.docs) {
      final data = doc.data();
      dynamic rawStartDate = data['startDate'];
      DateTime startDate;

      if (rawStartDate is Timestamp) {
        startDate = rawStartDate.toDate();
      } else if (rawStartDate is String) {
        startDate = DateTime.parse(rawStartDate);
      } else {
        throw Exception("Unsupported startDate type: ${rawStartDate.runtimeType}");
      }
      userId = widget.userId;
      print(data['userId']);
      print(userId);

      if (startDate.year == selectedDate.year &&
          startDate.month == selectedDate.month &&
          startDate.day == selectedDate.day&&
          data['userId'] == userId) {

        calendarEvents.add({
          'title': data['title'],
          'startTime': data['startTime'] != null
              ? '${data['startTime']['hour'].toString().padLeft(2, '0')}:${data['startTime']['minute'].toString().padLeft(2, '0')}'
              : null,
          'endTime': data['endTime'] != null
              ? '${data['endTime']['hour'].toString().padLeft(2, '0')}:${data['endTime']['minute'].toString().padLeft(2, '0')}'
              : null,
        });
      }
      print("오잉");
      print(calendarEvents);
    }

    final allTasksData = todoTasks.map((task) => {
      'title': task.title,
      'importance': task.importance ?? 1,
      'urgency': task.urgency ?? 1,
      'dueDate': task.dueDate != null ? task.dueDate!.toIso8601String().split('T').first : "없음",
      'time': task.time, // 시작 시간 추가
      'endTime': task.endTime, // 종료 시간 추가
    }).toList();

    if (allTasksData.isEmpty && calendarEvents.isEmpty) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 생성할 투두/일정이 없습니다!')),
      );
      return;
    }







    // AI에게 일정 + 투두 보내서 시간 배정 포함 스케줄 요청
    //final aiSchedule = await _getScheduleFromAI(allTasksData, calendarEvents);


    // ========== 새로운 AI 스케줄링 로직 (두 번째 코드에서 가져옴) ==========

    int _calculateDuration(String? start, String? end) {
      if (start == null || end == null) return 1;

      try {
        final startParts = start.split(':').map(int.parse).toList();
        final endParts = end.split(':').map(int.parse).toList();

        final startMinutes = startParts[0] * 60 + startParts[1];
        final endMinutes = endParts[0] * 60 + endParts[1];

        final duration = ((endMinutes - startMinutes) / 60).round();
        return duration > 0 ? duration : 1;
      } catch (e) {
        return 1;
      }
    }

    //이벤트 넣기 작업들을 새로운 형식 포맷팅

    final List<String> formattedCalendarEvents = [];

    for (var event in calendarEvents) {
      // aiSchedule에 추가

      // 포맷팅된 문자열 생성
      final name = event['title'] ?? '';
      final importance = 1; // 캘린더 이벤트는 기본값 1
      final urgency = 1; // 캘린더 이벤트는 기본값 1
      final duration = _calculateDuration(event['startTime'], event['endTime']);
      final startTime = event['startTime'] ?? '0';
      final endTime = event['endTime'] ?? '0';

      final formattedEvent = '(N: $name, I: $importance, U: $urgency, D: $duration, T: $startTime, T: $endTime)';
      formattedCalendarEvents.add(formattedEvent);
    }

// 또는 map을 사용해서 한 번에 처리하는 방법:
    final List<String> formattedCalendarEvents2 = calendarEvents.map((event) {

      // 포맷팅된 문자열 생성
      final name = event['title'] ?? '';
      final importance = 5;
      final urgency = 5;
      final duration = _calculateDuration(event['startTime'], event['endTime']);
      final startTime = event['startTime'] ?? '0';
      final endTime = event['endTime'] ?? '0';

      return '(N: $name, I: $importance, U: $urgency, D: $duration, T: $startTime, T: $endTime)';
    }).toList();

    print("일정포멧팅");
    print(formattedCalendarEvents2);


    // Todo 작업들을 새로운 형식으로 포맷팅
    final List<String> formattedList = todoTasks.map((task) {
      final name = task.title;
      final importance = task.importance ?? 1;
      final urgency = task.urgency ?? 1;
      final duration = _calculateDuration(task.time, task.endTime);
      final startTime = task.time ?? '0';
      final endTime = task.endTime ?? '0';

      return '(N: $name, I: $importance, U: $urgency, D: $duration, T: $startTime, T: $endTime)';
    }).toList();

    // 유저 선호도 정리
    Map<String, dynamic> userPreferences = await _getUserPreferences();

    // 🔹 1. 수면 종료 시간 파싱 (S)
    String sleepSchedule = userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00';
    int sleepEndHour = 7; // 기본값

    try {
      final sleepEndStr = sleepSchedule.split('~').last.trim();
      final parts = sleepEndStr.split(' ');
      final ampm = parts[0];
      final hourMinute = parts[1];
      int hour = int.parse(hourMinute.split(':')[0]);

      if (ampm == 'PM' && hour != 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      sleepEndHour = hour;
    } catch (e) {
      print('수면 종료 시간 파싱 실패: $e');
    }

    // 🔹 2. 휴식 시간 파싱 (H)
    String breakFrequency = userPreferences['breakFrequency'] ?? '1시간마다';
    int breakHour = 1; // 기본값

    try {
      final hourMatch = RegExp(r'\d+').firstMatch(breakFrequency);
      if (hourMatch != null) {
        int value = int.parse(hourMatch.group(0)!);

        if (breakFrequency.contains('분')) {
          breakHour = (value / 60).ceil();
        } else {
          breakHour = value;
        }
      }
    } catch (e) {
      print('휴식 시간 파싱 실패: $e');
    }

    // 🔹 최종 문자열로 조합
    String result = '[S: $sleepEndHour, H: $breakHour]';
    String fullOutput = '$result${formattedList.join('')}${formattedCalendarEvents2.join('')}';

    print(fullOutput);

    // 서버 URL 설정
    final String serverUrl = 'https://railwavve-production-68d4.up.railway.app/schedule_';

    List<Map<String, dynamic>> aiSchedule_ = [];

    try {
      // HTTP POST 요청 보내기
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'input_text': fullOutput}),
      );

      if (response.statusCode == 200) {
        // 성공적으로 응답 받음
        final data = json.decode(response.body);

        String algorithmOutput = data['algorithm_output'] ?? '결과 없음';
        String geminiOutput = data['gemini_output'] ?? '결과 없음';

        print("연결됨: $algorithmOutput");
        print("연결됨: $geminiOutput");

        // Gemini 출력에서 작업 정보 파싱
        final RegExp taskRegExp = RegExp(r'\(N: (.*?),.*?T: (.*?), T: (.*?)\)');
        final matches = taskRegExp.allMatches(geminiOutput);

        // AI 응답을 기존 Todo 작업들에 적용하고 aiSchedule 생성
        for (final match in matches) {
          final title = match.group(1)?.trim();
          final startTime = match.group(2)?.trim();
          final endTime = match.group(3)?.trim();

          if (title != null && startTime != null && endTime != null) {
            // 기존 todo 작업에서 해당 제목 찾기
            for (var task in todoTasks) {
              if (task.title.trim() == title) {
                print('🛠 업데이트 중: $title → $startTime ~ $endTime');

                // aiSchedule에 추가할 데이터 생성
                aiSchedule_.add({
                  'id': task.id,
                  'title': title,
                  'time': startTime,
                  'endTime': endTime,
                  'priority': task.importance ?? 1,
                  'description': task.description,
                  'memo': task.memo,
                  'location': task.location,
                  'dueDate': task.dueDate?.toIso8601String().split('T').first ?? "없음",
                });
                break;
              }
            }
            for (var task in calendarEvents) {
              if (task['title'] == title) {
                print('🛠 업데이트 중: $title → $startTime ~ $endTime');

                // aiSchedule에 추가할 데이터 생성
                aiSchedule_.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString() + '_event',
                  'title': title,
                  'time': startTime,
                  'endTime': endTime,
                  'priority': 1,
                  'description': '캘린더 이벤트',
                  'memo': null,
                  'location': null,
                  'dueDate': "없음",
                });

                break;
              }
            }
          }
        }

        // 캘린더 이벤트들도 aiSchedule에 추가 (시간이 고정된 이벤트들)
        /*for (var event in calendarEvents) {
          aiSchedule_.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_event',
            'title': event['title'],
            'time': event['startTime'],
            'endTime': event['endTime'],
            'priority': 1,
            'description': '캘린더 이벤트',
            'memo': null,
            'location': null,
            'dueDate': "없음",
          });
        }*/

      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 스케줄링 실패: $e')),
      );
      return;
    }

    //으앙




    if (aiSchedule_.isEmpty) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 스케줄링 실패 또는 결과가 없습니다!')),
      );
      return;
    }




    // 기존 스케줄 초기화
    final dateKey = _taskDataService.dateToKey(selectedDate);
    _taskDataService.plannerTasksByDate[dateKey] = [];


    for (var item in aiSchedule_){
      print("현세");
      print(item);

      if (item['time'] != null) {
        item['time'] = convertTimeIfNeeded(item['time']);
      }
      if (item['endTime'] != null) {
        item['endTime'] = convertTimeIfNeeded(item['endTime']);
      }

      print("변환 후:");
      print("time: ${item['time']}, endTime: ${item['endTime']}");
    }



    // AI가 준 스케줄대로 Todo_Task 생성 및 저장
    for (var item in aiSchedule_) {
      final int priority = item['priority'] ?? 1;
      // Generate unique ID for new tasks if not provided
      String taskId = item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() + '_${_taskDataService.plannerTasksByDate[dateKey]?.length ?? 0}';

      final task = Todo_Task(
        id: taskId,
        userId: userId, // userId 추가 (현재 로그인한 사용자 ID)
        title: item['title'] ?? '제목 없음',
        date: selectedDate,
        time: item['time'],
        endTime: _normalizeTime(item['endTime']),
        importance: priority,
        urgency: priority,
        isImportant: priority >= 2,
        isUrgent: priority >= 3,
        description: item['description'],
        memo: item['memo'],
        location: item['location'],
        isCompleted: false,
        color: null,
        dueDate: (item['dueDate'] != null && item['dueDate'] != "없음" && item['dueDate'].toString().isNotEmpty)
            ? DateTime.tryParse(item['dueDate']) ?? null
            : null,
        notificationId: null,
        reminderMinutesBefore: null,
        isRepeating: false, // 기본값 추가
        repeatOption: null,
        repeatDays: null,
        repeatCustomDays: null,
      );

      _taskDataService.addPlannerTask(task);

      // Debug logs to verify task creation
      print('Added planner task: ${task.title} at ${task.time}');
    }

    // Save changes to storage/database if needed
    for (final task in _taskDataService.plannerTasksByDate[dateKey] ?? []) {
      await _taskDataService.savePlannerTaskToFirestore(task);
    }

    // Ensure UI gets rebuilt with the new data
    setState(() {
      updateProgress();
      isLoading = false;

      // Reset planner view to force rebuild
      isPlannerView = false;
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          isPlannerView = true;
        });
      });
    });






    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 플래너가 생성되었습니다!')),
    );
  }



  Future<Map<String, dynamic>> _getUserPreferences() async {
    Map<String, dynamic> preferences = {
      'preferredTimeOfDay': '아침', // 기본값
      'sleepSchedule': 'PM 11:00 ~ AM 07:00', // 기본값
      'breakFrequency': '1시간마다', // 기본값
    };

    try {
      if (userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && userData.containsKey('preferences')) {
            final userPrefs = userData['preferences'];
            if (userPrefs is Map) {
              // 각 선호도 항목 추출
              if (userPrefs.containsKey('preferredTimeOfDay')) {
                preferences['preferredTimeOfDay'] =
                userPrefs['preferredTimeOfDay'];
              }

              if (userPrefs.containsKey('sleepSchedule')) {
                preferences['sleepSchedule'] = userPrefs['sleepSchedule'];
              }

              if (userPrefs.containsKey('breakFrequency')) {
                preferences['breakFrequency'] = userPrefs['breakFrequency'];
              }
            }
          }
        }
      }
    } catch (e) {
      print('사용자 선호도 불러오기 오류: $e');
    }

    return preferences;
  }


  Future<List<dynamic>> _getScheduleFromAI(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar) async {

    // 디버깅
    print('Tasks sent to server: $tasks');
    print('Calendar sent to server: $calendar');

    // 서버 URL 결정 (다양한 환경 지원)
    const List<String> possibleUrls = [
      'http://10.0.2.2:5001',       // 안드로이드 에뮬레이터
      'http://192.168.219.110:5001', // 서버 실제 IP (로컬 네트워크)
      'http://127.0.0.1:5001',      // 로컬호스트
      'http://localhost:5001'       // 로컬호스트 (이름)
    ];

    // 요청 데이터 준비
    final requestBody = json.encode({
      'tasks': tasks,
      'calendar': calendar,
    });

    print('Request body: $requestBody');

    // 각 URL에 시도
    for (String url in possibleUrls) {
      try {
        print('Trying connection to: $url/schedule');

        final response = await http
            .post(
          Uri.parse('$url/schedule'),
          headers: {"Content-Type": "application/json"},
          body: requestBody,
        )
            .timeout(const Duration(seconds: 10));

        print('Response from $url - Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // 응답 데이터 구조 확인
          if (data is Map && data.containsKey('schedule')) {
            final schedule = data['schedule'];

            if (schedule != null && schedule is List) {
              print('Successfully received schedule with ${schedule.length} items');
              return schedule;
            } else {
              print('Server returned empty or invalid schedule format');
            }
          } else {
            print('Invalid response format: $data');
          }
        }
      } catch (e) {
        print('Error with URL $url: $e');
      }
    }

    // 모든 연결 시도 실패 시 로컬 시뮬레이션
    print("All connection attempts failed. Using fallback local scheduling.");
    return _generateLocalSchedule(tasks, calendar);
  }

  // _generateLocalSchedule 함수 수정
  List<Map<String, dynamic>> generateLocalSchedule(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar) {

    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 1. 캘린더 이벤트 먼저 추가 (고정 일정)
    for (var event in calendar) {
      if (event['startTime'] != null) {
        // 시간 정규화
        final normalizedStartTime = _normalizeTime(event['startTime']);
        final normalizedEndTime = _normalizeTime(event['endTime']);

        int startHour;
        try {
          startHour = int.parse(normalizedStartTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        int endHour;
        if (normalizedEndTime != null) {
          try {
            endHour = int.parse(normalizedEndTime.split(':')[0]);
            endHour = endHour.clamp(0, 23); // 범위 확인
          } catch (e) {
            endHour = startHour + 1; // 기본값
          }
        } else {
          endHour = startHour + 1;
        }

        // 시간이 뒤바뀐 경우 수정
        if (endHour < startHour) {
          endHour = startHour + 1;
        }

        // 시간대 차지 표시
        for (int h = startHour; h <= endHour; h++) {
          occupiedHours.add(h.clamp(0, 23));
        }

        schedule.add({
          'id': 'cal_${schedule.length}',
          'title': '(일정) ${event['title']}',
          'time': normalizedStartTime,
          'endTime': normalizedEndTime ?? '${(startHour + 1).toString().padLeft(2, '0')}:00',
          'priority': 3, // 최우선
          'description': '캘린더 일정',
          'memo': '',
          'location': event['location'] ?? '',
        });
      }
    }

    // 2. 작업 중요도/긴급도 기준 정렬
    tasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore); // 높은 점수가 먼저 오도록
    });

    // 3. 먼저 사용자가 지정한 시간이 있는 작업 추가
    for (var task in tasks) {
      // 사용자가 지정한 시간이 있는지 확인
      final userTime = task['time'];

      if (userTime != null && userTime.toString().isNotEmpty) {
        // 시간 정규화
        final normalizedTime = _normalizeTime(userTime.toString());
        final normalizedEndTime = _normalizeTime(task['endTime']?.toString());

        // 시작 시간의 시간대만 추출
        int startHour;
        try {
          startHour = int.parse(normalizedTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        // 종료 시간 설정
        String endTime;
        if (normalizedEndTime != null && normalizedEndTime.isNotEmpty) {
          endTime = normalizedEndTime;
        } else {
          // 기본 종료 시간은 시작 + 1시간
          endTime = '${((startHour + 1) % 24).toString().padLeft(2, '0')}:00';
        }

        // 시간대 차지 표시
        occupiedHours.add(startHour);

        // 중요도/긴급도에 따른 우선순위 설정
        final importance = task['importance'] ?? 1;
        final urgency = task['urgency'] ?? 1;
        final priority = importance > urgency ? importance : urgency;

        schedule.add({
          'id': 'task_${schedule.length}',
          'title': task['title'],
          'time': normalizedTime,
          'endTime': endTime,
          'priority': priority,
          'description': '중요도: $importance, 긴급도: $urgency',
          'memo': '',
          'location': '',
          'dueDate': task['dueDate'],
        });

        // 이미 처리된 작업은 표시
        task['_processed'] = true;
      }
    }

    // 4. 남은 시간대에 시간이 지정되지 않은 작업 배치
    int startHour = 9; // 오전 9시부터 시작

    for (var task in tasks) {
      // 이미 처리된 작업은 건너뛰기
      if (task['_processed'] == true) continue;

      // 하루 업무 시간 9시-21시로 제한
      if (startHour >= 21) break;

      // 사용 가능한 시간 찾기
      while (occupiedHours.contains(startHour)) {
        startHour++;
        if (startHour >= 21) break;
      }

      if (startHour >= 21) break;

      // 중요도/긴급도에 따른 우선순위 설정
      final importance = task['importance'] ?? 1;
      final urgency = task['urgency'] ?? 1;
      final priority = importance > urgency ? importance : urgency;

      schedule.add({
        'id': 'task_${schedule.length}',
        'title': task['title'],
        'time': '${startHour.toString().padLeft(2, '0')}:00',
        'endTime': '${(startHour + 1).toString().padLeft(2, '0')}:00',
        'priority': priority,
        'description': '중요도: $importance, 긴급도: $urgency',
        'memo': '',
        'location': '',
        'dueDate': task['dueDate'],
      });

      occupiedHours.add(startHour);
      startHour++;
    }

    // 시간순 정렬
    schedule.sort((a, b) {
      if (a['time'] == null) return 1;
      if (b['time'] == null) return -1;
      return a['time'].toString().compareTo(b['time'].toString());
    });

    return schedule;
  }

}

// 개선된 월 선택기 위젯
class ImprovedMonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onMonthChanged;

  const ImprovedMonthSelector({
    Key? key,
    required this.selectedDate,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              final newDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),
          GestureDetector(
            onTap: () => _showMonthYearPicker(context),
            child: Text(
              '${selectedDate.year}년 ${selectedDate.month}월',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () {
              final newDate = DateTime(selectedDate.year, selectedDate.month + 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          child: YearPicker(
            selectedDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onChanged: (DateTime dateTime) {
              onMonthChanged(dateTime);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

// 개선된 주간 캘린더 위젯
class EnhancedWeeklyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const EnhancedWeeklyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  _EnhancedWeeklyCalendarState createState() => _EnhancedWeeklyCalendarState();
}

class _EnhancedWeeklyCalendarState extends State<EnhancedWeeklyCalendar> {
  late PageController _pageController;
  late int _currentPage;
  final int _totalWeeks = 100;
  late DateTime _baseDate;
  late DateTime _currentStartDate;

  @override
  void initState() {
    super.initState();
    _baseDate = _findFirstDayOfWeek(DateTime.now().subtract(Duration(days: 50 * 7)));
    _currentPage = _getPageForDate(widget.selectedDate);
    _pageController = PageController(initialPage: _currentPage);
    _currentStartDate = _getStartDateForPage(_currentPage);
  }

  @override
  void didUpdateWidget(covariant EnhancedWeeklyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final newPage = _getPageForDate(widget.selectedDate);
      if (newPage != _currentPage) {
        _currentPage = newPage;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _currentStartDate = _getStartDateForPage(_currentPage);
      }
    }
  }

  DateTime _findFirstDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _getPageForDate(DateTime date) {
    final firstDayOfWeek = _findFirstDayOfWeek(date);
    final diffDays = firstDayOfWeek.difference(_baseDate).inDays;
    return (diffDays / 7).round();
  }

  DateTime _getStartDateForPage(int page) {
    return _baseDate.add(Duration(days: page * 7));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
            _currentStartDate = _getStartDateForPage(page);
          });
        },
        itemBuilder: (context, index) {
          final weekStart = _getStartDateForPage(index);
          return _buildWeek(weekStart);
        },
        itemCount: _totalWeeks,
      ),
    );
  }

  Widget _buildWeek(DateTime weekStart) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final currentDate = weekStart.add(Duration(days: index));
            return Container(
              width: 40,
              child: Center(
                child: Text(
                  _getWeekdayString(currentDate.weekday),
                  style: TextStyle(
                    color: currentDate.weekday >= 6
                        ? (currentDate.weekday == 6 ? Colors.blue : Colors.red)
                        : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final currentDate = weekStart.add(Duration(days: index));
            final isSelected = _isSameDay(currentDate, widget.selectedDate);
            final isToday = _isSameDay(currentDate, DateTime.now());
            return GestureDetector(
              onTap: () => widget.onDateSelected(currentDate),
              child: Container(
                width: 40,
                height: 40,
                decoration: isSelected
                    ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.2),
                )
                    : isToday
                    ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple, width: 1),
                )
                    : null,
                child: Center(
                  child: Text(
                    '${currentDate.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.purple
                          : (currentDate.weekday >= 6
                          ? (currentDate.weekday == 6 ? Colors.blue : Colors.red)
                          : Colors.black87),
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _getWeekdayString(dynamic weekday) {
    // weekday를 안전하게 int로 변환
    int day;
    if (weekday is String) {
      day = int.tryParse(weekday) ?? 1;
    } else if (weekday is int) {
      day = weekday;
    } else {
      day = 1; // 기본값
    }

    switch (day) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

Color _getFixedColorForTask(String title) {
  final colors = [
    Colors.purple.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.orange.shade100,
    Colors.red.shade100,
    Colors.teal.shade100,
    Colors.amber.shade100,
  ];
  return colors[title.hashCode % colors.length];
}


// 랜덤한 밝은 파스텔 색상 생성
Color getBrightPastelColor() {
  final Random random = Random();
  final List<Color> brightPastelColors = [
    const Color(0xFFFFE6E6),
    const Color(0xFFFFEDCC),
    const Color(0xFFFFFFCC),
    const Color(0xFFE6FFCC),
    const Color(0xFFCCFFE1),
    const Color(0xFFCCFFFF),
    const Color(0xFFCCE6FF),
    const Color(0xFFE6CCFF),
    const Color(0xFFFDD5DF),
    const Color(0xFFFFDAB9),
    const Color(0xFFE0F7FA),
    const Color(0xFFF1F8E9),
    const Color(0xFFFCE4EC),
    const Color(0xFFF3E5F5),
    const Color(0xFFE8F5E9),
  ];
  return brightPastelColors[random.nextInt(brightPastelColors.length)];
}
