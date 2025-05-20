import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import '../Calendar/models/event.dart';
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
  final CollectionReference todoCollection = FirebaseFirestore.instance.collection('todos');
  final CollectionReference plannerCollection = FirebaseFirestore.instance.collection('planners');

// 사용자 ID 저장 변수
  String? currentUserId;

// 사용자 ID 설정 메서드
  void setUserId(String userId) {
    currentUserId = userId;
  }

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
        final dateKey = dateToKey(dateTime);

        // 시간 정보 디버그 출력
        print('투두 데이터 로드: ${data['title']}, 시간: ${data['time']}, 종료 시간: ${data['endTime']}');

        final task = Todo_Task(
          title: data['title'],
          description: data['description'],
          time: data['time'],  // 그대로 저장
          endTime: data['endTime'],  // 그대로 저장
          date: dateTime,
          isImportant: data['isImportant'] ?? false,
          memo: data['memo'],
          location: data['location'],
          importance: data['importance'] ?? 1,
          urgency: data['urgency'] ?? 1,
          isCompleted: data['isCompleted'] ?? false,
          dueDate: data['dueDate'] != null
              ? DateTime.parse(data['dueDate'])
              : null,
        );

        if (!todoTasksByDate.containsKey(dateKey)) {
          todoTasksByDate[dateKey] = [];
        }

        // 중복 체크: 동일한 제목과 날짜의 태스크가 있는지 확인
        bool isDuplicate = todoTasksByDate[dateKey]!.any((t) =>
        t.title == task.title && t.date.day == task.date.day &&
            t.date.month == task.date.month && t.date.year == task.date.year);

        if (!isDuplicate) {
          todoTasksByDate[dateKey]!.add(task);
        }
      }

      // Planner 데이터 로드
      final plannerSnapshot = await plannerCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in plannerSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTime = DateTime.parse(data['date']);
        final dateKey = dateToKey(dateTime);

        final task = Todo_Task(
          title: data['title'],
          description: data['description'],
          time: data['time'],
          endTime: data['endTime'],
          date: dateTime,
          isImportant: data['isImportant'] ?? false,
          //isUrgent: data['isUrgent'] ?? false,
          memo: data['memo'],
          location: data['location'],
          importance: data['importance'] ?? 1,
          urgency: data['urgency'] ?? 1,
          isCompleted: data['isCompleted'] ?? false,
          dueDate: data['dueDate'] != null
              ? DateTime.parse(data['dueDate'])
              : null,
        );

        if (!plannerTasksByDate.containsKey(dateKey)) {
          plannerTasksByDate[dateKey] = [];
        }

        // 중복 체크: 동일한 제목과 날짜의 태스크가 있는지 확인
        bool isDuplicate = plannerTasksByDate[dateKey]!.any((t) =>
        t.title == task.title && t.date.day == task.date.day &&
            t.date.month == task.date.month && t.date.year == task.date.year);

        if (!isDuplicate) {
          plannerTasksByDate[dateKey]!.add(task);
        }
      }

      print('Firestore 데이터 로드 완료: Todo ${todoTasksByDate.length}, Planner ${plannerTasksByDate.length}');
    } catch (e) {
      print('Firestore 데이터 로드 오류: $e');
    }
  }

// Todo Task를 Firestore에 저장
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
        //'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Todo Task 저장 오류: $e');
    }
  }

// Planner Task를 Firestore에 저장
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
        //'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Planner Task 저장 오류: $e');
    }
  }

// Task 상태 업데이트 (완료/미완료)
  Future<void> updateTaskCompletionInFirestore(Todo_Task task, bool isCompleted) async {
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

  // 특정 날짜의 Planner 작업 모두 삭제 (최종 수정 버전)
  Future<void> clearPlannerTasksForDate(DateTime date) async {
    if (currentUserId == null) return;

    final dateKey = dateToKey(date);

    try {
      // 1. 먼저 로컬 캐시 데이터 삭제 (중요!)
      plannerTasksByDate[dateKey] = [];

      // 2. Firestore에서 해당 날짜의 문서 검색
      final dateStr = date.toIso8601String();
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('date', isEqualTo: dateStr)
          .get();

      // 3. Firestore 문서 삭제
      if (plannerQuery.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in plannerQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 4. 로컬 캐시가 확실히 비워졌는지 한 번 더 확인
      if (plannerTasksByDate.containsKey(dateKey)) {
        plannerTasksByDate[dateKey] = [];
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 날짜 비교 메서드
  bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  List<Todo_Task> getTodoTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    final tasks = todoTasksByDate[dateKey]?.where((task) =>
        isSameDate(task.date, date)).toList() ?? [];

    // 디버그 로그 추가
    for (var task in tasks) {
      print('가져온 할 일: ${task.title}, 시간: ${task.time}, 종료 시간: ${task.endTime}');
    }

    return tasks;
  }

  // Todo List 추가 메서드 수정
  void addTodoTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }
    if (!todoTasksByDate[dateKey]!.any((existingTask) =>
    isSameDate(existingTask.date, task.date) &&
        existingTask.title == task.title)) {
      todoTasksByDate[dateKey]!.add(task);
      // Firestore에 저장
      saveTodoTaskToFirestore(task);
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
    final completedTasks = todoTasks.where((task) => task.isCompleted).length +
        plannerTasks.where((task) => task.isCompleted).length;
    return (completedTasks / totalTasks) * 100;
  }

  void updateTaskStatus(Todo_Task task, bool isCompleted) {
    final dateKey = dateToKey(task.date);
    if (todoTasksByDate.containsKey(dateKey)) {
      try {
        final todoTask = todoTasksByDate[dateKey]!
            .firstWhere((t) => t.title == task.title);
        todoTask.isCompleted = isCompleted;
      } catch (e) {}
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      try {
        final plannerTask = plannerTasksByDate[dateKey]!
            .firstWhere((t) => t.title == task.title);
        plannerTask.isCompleted = isCompleted;
      } catch (e) {}
    }
    // Firestore 업데이트 - 수정된 부분
    this.updateTaskCompletionInFirestore(task, isCompleted);
  }
}


class DailyPlannerPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> calendarData;

  const DailyPlannerPage({
    Key? key,
    required this.userId,
    this.calendarData = const [],
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
    final args = ModalRoute
        .of(context)
        ?.settings
        .arguments as Map<String, dynamic>?;
    userId = args?['userId'] ?? '';
    print('📌 userId 받은 값: $userId');
  }

  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
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

  // 사용자 선호도 정보 가져오기 (수정된 함수)
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

// 파이어스토어에서 데이터 로드하는 메서드
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

  void changeSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      updateProgress();
    });
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 추가 위치: DailyPlannerPage.dart의 _DailyPlannerPageState 클래스 내부 (다른 메서드들과 같은 레벨)에 다음 메서드 추가

  Widget _buildDailyReminder() {
    // 오늘의 할 일과 일정 가져오기
    final todayTasks = _taskDataService.getTodoTasksForDate(selectedDate);
    final todayEvents = widget.calendarData.where((event) {
      final eventDate = DateTime.tryParse(event['date'] ?? '');
      return eventDate?.year == selectedDate.year &&
          eventDate?.month == selectedDate.month &&
          eventDate?.day == selectedDate.day;
    }).toList();

    // 할 일이나 일정이 없으면 위젯을 표시하지 않음
    if (todayTasks.isEmpty && todayEvents.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFE6E0FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(Icons.assistant, color: Color(0xFF9D8CFF)),
              SizedBox(width: 8),
              Text(
                '오늘의 리마인더',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF4A4A4A),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // 캘린더 일정 리스트
          if (todayEvents.isNotEmpty) ...[
            Text(
              '📅 캘린더 일정:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF4A4A4A),
              ),
            ),
            SizedBox(height: 4),
            ...todayEvents.take(3).map((event) =>
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    '• ${event['title']} ${event['startTime'] != null
                        ? '(${event['startTime']})'
                        : ''}',
                    style: TextStyle(fontSize: 13),
                  ),
                )
            ),
            if (todayEvents.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  '외 ${todayEvents.length - 3}개 일정',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            SizedBox(height: 4),
          ],
          // 할일 리스트
          if (todayTasks.isNotEmpty) ...[
            Text(
              '📝 할 일:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF4A4A4A),
              ),
            ),
            SizedBox(height: 4),
            ...todayTasks.take(3).map((task) =>
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    '• ${task.title}${task.time != null
                        ? ' (${task.time})'
                        : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                )
            ),
            if (todayTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  '외 ${todayTasks.length - 3}개 할 일',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
          ],
        ],
      ),
    );
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
      bottomNavigationBar: BottomNav(initialIndex: 1, userId: widget.userId),
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
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // 오늘의 할 일과 일정을 가져옴
    final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
    final calendarEvents = _getEventsForSelectedDate();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildReminderBubble(),
          // 상단 버튼 영역 (날짜 표시 제거됨)
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
                // 리마인더 표시 (새로 추가)
                if (isToday &&
                    (todoTasks.isNotEmpty || calendarEvents.isNotEmpty))
                  GestureDetector(
                    onTap: _showReminderDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              size: 18,
                              color: Colors.purple.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '오늘의 리마인더',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                // 일정 전체 삭제 버튼
                IconButton(
                  onPressed: () {
                    // 확인 대화상자 표시
                    showDialog(
                      context: context,
                      builder: (context) =>
                          AlertDialog(
                            backgroundColor: Colors.white, // 배경색을 흰색으로 설정
                            title: const Text('일정 초기화'),
                            content: const Text('이 날짜의 모든 일정을 삭제하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _taskDataService
                                      .clearPlannerTasksForDate(selectedDate);
                                  setState(() {
                                    updateProgress();
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                    '삭제', style: TextStyle(color: Colors.red)),
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

          // 시간별 일정 목록 (기존 코드)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 24,
            itemBuilder: (context, index) {
              final hour = index;
              final time = DateTime(2025, 1, 1, hour);
              final amPm = hour < 12 ? 'AM' : 'PM';
              final displayHour = hour % 12 == 0 ? 12 : hour % 12;
              final timeLabel = '$displayHour $amPm';

              // 현재 시간인지 확인
              final isCurrentHour = isToday && now.hour == hour;

              // 현재 시간대에 해당하는 일정들
              final hourTasks = tasks.where((task) {
                final taskStart = _parseTimeToDateTime(task.time);
                return taskStart != null && taskStart.hour == hour;
              }).toList();

              return Container(
                decoration: BoxDecoration(
                  color: isCurrentHour ? Colors.purple.withOpacity(0.05) : null,
                  // 보라색으로 변경
                  border: isCurrentHour
                      ? Border(
                    left: BorderSide(
                      color: Colors.purple.shade400, // 보라색으로 변경
                      width: 3,
                    ),
                  )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시간 표시 영역
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrentHour
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrentHour
                                  ? Colors.purple.shade700
                                  : Colors.grey.shade600, // 보라색으로 변경
                            ),
                          ),
                          if (isCurrentHour)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.purple.shade700, // 보라색으로 변경
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 일정 카드 영역
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: hourTasks.isEmpty
                            ? _buildEmptyTimeSlot(hour)
                            : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: hourTasks.map((task) =>
                                _buildTodoTaskCard(task)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

// 리마인더 대화상자 표시 함수 추가
  void _showReminderDialog() {
    final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
    final calendarEvents = _getEventsForSelectedDate();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.purple.shade700),
                const SizedBox(width: 10),
                const Text('오늘의 리마인더'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery
                    .of(context)
                    .size
                    .height * 0.6,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (calendarEvents.isNotEmpty) ...[
                    const Text(
                      '📅 오늘의 일정',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...calendarEvents.map((event) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                if (event.startTime != null)
                                  Text(
                                    '시간: ${event.startTime!.format(
                                        context)} ${event.endTime != null
                                        ? '~ ${event.endTime!.format(context)}'
                                        : ''}',
                                    style: TextStyle(
                                        color: Colors.blue.shade700),
                                  ),
                                if (event.location != null &&
                                    event.location!.isNotEmpty)
                                  Text(
                                    '장소: ${event.location}',
                                    style: TextStyle(
                                        color: Colors.blue.shade700),
                                  ),
                              ],
                            ),
                          ),
                        )),
                  ],

                  if (todoTasks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '📝 오늘의 할 일',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...todoTasks.map((task) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: task.isCompleted,
                                        onChanged: (value) {
                                          setState(() {
                                            _taskDataService.updateTaskStatus(
                                                task, value ?? false);
                                            updateProgress();
                                            Navigator.pop(context); // 대화상자 닫기
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (task.importance > 0) ...[
                                      const SizedBox(width: 32),
                                      Icon(Icons.star, size: 14,
                                          color: Colors.amber),
                                      Text(' ${task.importance}',
                                          style: TextStyle(fontSize: 12,
                                              color: Colors.amber.shade800)),
                                    ],
                                    if (task.urgency > 0) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.timer, size: 14,
                                          color: Colors.red.shade400),
                                      Text(' ${task.urgency}',
                                          style: TextStyle(fontSize: 12,
                                              color: Colors.red.shade800)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],

                  if (calendarEvents.isEmpty && todoTasks.isEmpty)
                    const Text('오늘은 특별한 일정이나 할 일이 없습니다. 편안한 하루 되세요!'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

// 선택된 날짜의 이벤트를 가져오는 헬퍼 함수
  List<Event> _getEventsForSelectedDate() {
    final events = <Event>[];

    try {
      // 날짜 문자열 포맷 (YYYY-MM-DD)
      final dateStr = "${selectedDate.year}-${selectedDate.month
          .toString()
          .padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      // Firestore에서 해당 날짜의
      FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .where('startDate', isEqualTo: dateStr)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();

          final startTime = data['startTime'] != null
              ? TimeOfDay(hour: data['startTime']['hour'],
              minute: data['startTime']['minute'])
              : null;

          final endTime = data['endTime'] != null
              ? TimeOfDay(
              hour: data['endTime']['hour'], minute: data['endTime']['minute'])
              : null;

          final event = Event(
            userId: data['userId'],
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            startDate: DateTime.parse(data['startDate']),
            endDate: DateTime.parse(data['endDate'] ?? data['startDate']),
            startTime: startTime,
            endTime: endTime,
            memo: data['memo'] ?? '',
            location: data['location'] ?? '',
          );

          events.add(event);
        }
      });
    } catch (e) {
      print('캘린더 이벤트 로드 오류: $e');
    }

    return events;
  }

// 빈 시간대 표시 위젯 - 빈칸으로 수정
  Widget _buildEmptyTimeSlot(int hour) {
    // 시간대별 배경색 결정 (낮/밤 구분)
    final isDaytime = hour >= 8 && hour < 18;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDaytime
            ? Colors.grey.withOpacity(0.03)
            : Colors.blueGrey.withOpacity(0.03),
      ),
      // "일정 없음" 텍스트와 아이콘 제거하여 빈칸으로 표시
    );
  }

// TodoTask 카드 위젯 - 레이아웃 변경
  Widget _buildTodoTaskCard(dynamic task) {
    final start = _parseTimeToDateTime(task.time);
    final end = _parseTimeToDateTime(task.endTime);
    final timeRange = (start != null && end != null)
        ? '${DateFormat.Hm().format(start)} ~ ${DateFormat.Hm().format(end)}'
        : '';

    // 완료 여부에 따른 스타일 조정
    final isCompleted = task.isCompleted;
    final taskColor = task.color ?? _getFixedColorForTask(task.title);

    // 마감일까지 남은 일수 계산
    int? daysLeft;
    String? dueStatus;
    if (task.dueDate != null) {
      final today = DateTime.now();
      final dueDay = DateTime(
          task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final difference = dueDay
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      daysLeft = difference;

      if (difference < 0) {
        dueStatus = '기한 초과';
      } else if (difference == 0) {
        dueStatus = '오늘 마감';
      } else if (difference == 1) {
        dueStatus = '내일 마감';
      } else if (difference <= 3) {
        dueStatus = '$difference일 남음';
      }
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 300,
      ),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : taskColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.grey.shade300 : taskColor.withOpacity(
              0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // 일정 상세보기 (구현 필요 없는 경우 주석 처리)
            // _showTaskDetailDialog(context, task);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목과 시간 영역 (가로로 배치)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ),

                    // 시간 표시
                    if (timeRange.isNotEmpty)
                      Text(
                        timeRange,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted ? Colors.grey : Colors.black54,
                        ),
                      ),

                    // 체크박스
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: task.isCompleted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        activeColor: Colors.purple.shade400, // 보라색으로 변경
                        onChanged: (bool? value) {
                          setState(() {
                            _taskDataService.updateTaskStatus(
                                task, value ?? false);
                            updateProgress();
                          });
                          if (value == true) {
                            _notificationService.showTaskCompletedNotification(
                                task.title);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 메모와 위치 정보 (가로로 배치)
                if (task.memo != null && task.memo!.isNotEmpty ||
                    task.location != null && task.location!.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메모 표시
                      if (task.memo != null && task.memo!.isNotEmpty)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              task.memo!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isCompleted ? Colors.grey : Colors
                                    .black87,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(width: 8),

                      // 위치 정보
                      if (task.location != null && task.location!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.05), // 보라색으로 변경
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.withOpacity(0.2), // 보라색으로 변경
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: isCompleted ? Colors.grey : Colors
                                    .purple, // 보라색으로 변경
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.location!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isCompleted ? Colors.grey : Colors
                                      .purple, // 보라색으로 변경
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 8),

                // 마감일 표시 (하단에 배치)
                if (task.dueDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: daysLeft != null && daysLeft < 0
                          ? Colors.red.withOpacity(0.1)
                          : daysLeft != null && daysLeft == 0
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.purple.withOpacity(0.1), // 보라색으로 변경
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event,
                          size: 14,
                          color: daysLeft != null && daysLeft < 0
                              ? Colors.red
                              : daysLeft != null && daysLeft == 0
                              ? Colors.orange
                              : Colors.purple, // 보라색으로 변경
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dueStatus ?? DateFormat('MM/dd').format(task
                              .dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: daysLeft != null && daysLeft <= 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: daysLeft != null && daysLeft < 0
                                ? Colors.red
                                : daysLeft != null && daysLeft == 0
                                ? Colors.orange
                                : Colors.purple, // 보라색으로 변경
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  DateTime? _parseTimeToDateTime(String? time) {
    if (time == null) return null;

    final match24 = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      return DateTime(0, 1, 1, hour, minute);
    }

    final match12 = RegExp(r'(AM|PM)\s(\d{1,2}):(\d{2})').firstMatch(time);
    if (match12 != null) {
      String period = match12.group(1)!;
      int hour = int.parse(match12.group(2)!);
      int minute = int.parse(match12.group(3)!);
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(0, 1, 1, hour, minute);
    }

    return null;
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
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute'; // 항상 HH:mm 형태로 반환
  }


  void _generateAIPlanner() async {
    // Show loading indicator while processing
    setState(() {
      isLoading = true;
    });

    final List<Todo_Task> todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);

    // Firebase에서 Calendar Event 가져오기 (시간 포함)
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .get();
    List<Map<String, dynamic>> calendarEvents = [];

    for (var doc in eventsSnapshot.docs) {
      final data = doc.data();

      // 날짜 처리 개선
      DateTime? startDate;
      if (data['startDate'] is Timestamp) {
        startDate = data['startDate'].toDate();
      } else if (data['startDate'] is String) {
        try {
          startDate = DateTime.parse(data['startDate']);
        } catch (e) {
          print('날짜 파싱 오류: ${data['startDate']}');
          continue;
        }
      } else if (data['date'] is Timestamp) {
        startDate = data['date'].toDate();
      } else if (data['date'] is String) {
        try {
          startDate = DateTime.parse(data['date']);
        } catch (e) {
          print('날짜 파싱 오류: ${data['date']}');
          continue;
        }
      }

      if (startDate == null) continue;

      if (startDate.year == selectedDate.year &&
          startDate.month == selectedDate.month &&
          startDate.day == selectedDate.day) {

        // 시간 형식 제대로 가져오기
        String? startTimeStr;
        String? endTimeStr;

        // Map 형식인 경우
        if (data['startTime'] is Map) {
          Map<String, dynamic> startTimeMap = data['startTime'];
          if (startTimeMap.containsKey('hour') && startTimeMap.containsKey('minute')) {
            int hour = startTimeMap['hour'];
            int minute = startTimeMap['minute'];
            startTimeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          }
        }
        // 문자열 형식인 경우
        else if (data['startTime'] is String) {
          startTimeStr = data['startTime'];
        }

        // Map 형식인 경우
        if (data['endTime'] is Map) {
          Map<String, dynamic> endTimeMap = data['endTime'];
          if (endTimeMap.containsKey('hour') && endTimeMap.containsKey('minute')) {
            int hour = endTimeMap['hour'];
            int minute = endTimeMap['minute'];
            endTimeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          }
        }
        // 문자열 형식인 경우
        else if (data['endTime'] is String) {
          endTimeStr = data['endTime'];
        }

        calendarEvents.add({
          'title': data['title'],
          'startTime': startTimeStr,
          'endTime': endTimeStr,
        });
      }
    }

    // 투두 일정 시간 형식 유지하도록 수정
    final allTasksData = todoTasks.map((task) {
      // 시간 디버그 출력
      print('투두 일정 시간 확인: ${task.title} - time: ${task.time}, endTime: ${task.endTime}');

      Map<String, dynamic> taskData = {
        'title': task.title,
        'importance': task.importance ?? 1,
        'urgency': task.urgency ?? 1,
        'dueDate': task.dueDate != null ? task.dueDate!
            .toIso8601String()
            .split('T')
            .first : "없음",
      };

      // 시간 정보가 있으면 추가
      if (task.time != null && task.time!.isNotEmpty) {
        taskData['time'] = task.time;
      }

      if (task.endTime != null && task.endTime!.isNotEmpty) {
        taskData['endTime'] = task.endTime;
      }

      return taskData;
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
    final aiSchedule = await _getScheduleFromAI(allTasksData, calendarEvents);

    if (aiSchedule.isEmpty) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 스케줄링 실패 또는 결과가 없습니다!')),
      );
      return;
    }

    // 기존 스케줄 초기화
    await _taskDataService.clearPlannerTasksForDate(selectedDate);
    final dateKey = _taskDataService.dateToKey(selectedDate);

    // AI가 준 스케줄대로 Todo_Task 생성 및 저장
    for (var item in aiSchedule) {
      // 디버그 출력
      print('AI 스케줄 항목: $item');

      final startTimeStr = item['time'];
      final endTimeStr = item['endTime'];

      // 우선순위 설정
      final int priorityLevel = item['priority'] ?? 1;

      DateTime? parsedDueDate;
      if (item['dueDate'] != null && item['dueDate'] != '없음') {
        try {
          parsedDueDate = DateTime.parse(item['dueDate']);
        } catch (e) {
          print('날짜 파싱 오류: ${item['dueDate']} - $e');
          parsedDueDate = null;
        }
      }

      String generatedTaskId = item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() +
          '_${_taskDataService.plannerTasksByDate[dateKey]?.length ?? 0}';

      final task = Todo_Task(
        id: generatedTaskId,
        title: item['title'] ?? '제목 없음',
        date: selectedDate,
        time: startTimeStr,
        endTime: endTimeStr,
        importance: priorityLevel,
        urgency: priorityLevel,
        isImportant: priorityLevel >= 2,
        description: item['description'],
        memo: item['memo'],
        location: item['location'],
        isCompleted: false,
        color: null,
        dueDate: parsedDueDate,
        notificationId: null,
        reminderMinutesBefore: null,
      );

      _taskDataService.addPlannerTask(task);
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

  Widget _buildReminderBubble() {
    // 오늘 일정 가져오기
    final todayCalendarEvents = _getEventsForSelectedDate();
    final todayTodoTasks = _taskDataService.getTodoTasksForDate(selectedDate);

    // 일정/할일이 없으면 표시하지 않음
    if (todayCalendarEvents.isEmpty && todayTodoTasks.isEmpty) {
      return SizedBox.shrink();
    }

    // 맞춤형 메시지 생성
    String message = _generateContextualMessage(
        todayCalendarEvents, todayTodoTasks);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFE6E0FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF9D8CFF),
              radius: 20,
              child: Icon(Icons.assistant, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "오늘의 리마인더",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// 맞춤형 메시지 생성 함수
  String _generateContextualMessage(List<Event> events, List<Todo_Task> tasks) {
    // 기본 메시지
    if (events.isEmpty && tasks.isEmpty) {
      return "오늘은 특별한 일정이 없습니다. 여유로운 하루 되세요!";
    }

    // 먼저 특정 키워드 기반 맞춤 메시지 확인
    for (var event in events) {
      final title = event.title.toLowerCase();

      // 여행 관련 일정
      if (title.contains('여행') || title.contains('trip')) {
        String destination = '';

        if (title.contains('일본'))
          destination = '일본';
        else if (title.contains('미국'))
          destination = '미국';
        else if (title.contains('유럽'))
          destination = '유럽';
        else if (title.contains('제주')) destination = '제주';

        if (destination.isNotEmpty) {
          return "$destination 여행을 가시는군요! 호텔과 항공권은 예약하셨나요?";
        }

        return "여행 준비는 잘 되고 있나요? 여권과 필수 준비물을 확인하세요.";
      }

      // 시험 관련 일정
      if (title.contains('시험') || title.contains('테스트') ||
          title.contains('exam')) {
        return "오늘 시험이 있네요. 충분히 준비하셨나요? 행운을 빕니다!";
      }

      // 미팅/회의 관련
      if (title.contains('회의') || title.contains('미팅')) {
        return "오늘 회의가 있습니다. 필요한 자료는 준비되었나요?";
      }
    }

    // 할 일 관련 메시지
    if (tasks.isNotEmpty) {
      final completedTasks = tasks
          .where((task) => task.isCompleted)
          .length;
      final totalTasks = tasks.length;

      if (completedTasks == 0) {
        return "오늘 할 일이 ${tasks.length}개 있습니다. 지금 시작해볼까요?";
      } else {
        return "오늘 할 일 ${totalTasks}개 중 ${completedTasks}개를 완료했습니다. 잘하고 계세요!";
      }
    }

    // 기본 메시지
    return "오늘 하루도 화이팅하세요!";
  }

  Future<List<dynamic>> _getScheduleFromAI(List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar) async {
    // 사용자 선호도 정보 가져오기
    Map<String, dynamic> userPreferences = await _getUserPreferences();

    // 디버깅
    print('Tasks sent to server: $tasks');
    print('Calendar sent to server: $calendar');
    print('User preferences: $userPreferences');

    const List<String> possibleUrls = [
      'https://railwavve-production-68d4.up.railway.app',       // 안드로이드 에뮬레이터
      'https://railwavve-production-68d4.up.railway.app/', // 서버 실제 IP (로컬 네트워크)
      'https://railwavve-production-68d4.up.railway.app/',      // 로컬호스트
      'https://railwavve-production-68d4.up.railway.app/'       // 로컬호스트 (이름)
    ];

    // 요청 데이터 준비
    final requestBody = json.encode({
      'tasks': tasks,
      'calendar': calendar,
      'userPreferences': userPreferences, // 사용자 선호도 정보 추가
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
          // 응답 본문 처리 개선
          try {
            final data = json.decode(response.body);

            // 응답이 직접 리스트인 경우 (서버 응답 형식 변경)
            if (data is List) {
              print('Received list format directly: ${data.length} items');
              return data;
            }

            // 기존 예상 형식 (schedule 키가 있는 맵)
            else if (data is Map && data.containsKey('schedule')) {
              final schedule = data['schedule'];
              if (schedule != null && schedule is List) {
                print('Successfully received schedule with ${schedule.length} items');
                return schedule;
              }
            }

            print('Unexpected data format: $data');
            // 응답 형식이 예상과 다르더라도 사용 가능한 리스트라면 사용
            if (data is List) {
              return data;
            }
          } catch (e) {
            print('JSON parsing error: $e');
          }
        }
      } catch (e) {
        print('Error with URL $url: $e');
      }
    }

    // 모든 연결 시도 실패 시 로컬 시뮬레이션
    print("All connection attempts failed. Using fallback local scheduling.");
    return _generateLocalSchedule(tasks, calendar, userPreferences);
  }

  List<Map<String, dynamic>> _generateLocalSchedule(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar,
      Map<String, dynamic> userPreferences) {
    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 캘린더 이벤트 먼저 추가 (고정 일정)
    for (var event in calendar) {
      if (event['startTime'] != null) {
        int? startHour;
        // 시간 형식 유연하게 처리
        if (event['startTime'] is String) {
          final startTimeStr = event['startTime'].toString();

          // HH:MM 형식 확인
          if (startTimeStr.contains(':')) {
            startHour = int.tryParse(startTimeStr.split(':')[0]);
          }
        }

        int? endHour;
        if (event['endTime'] != null && event['endTime'] is String) {
          final endTimeStr = event['endTime'].toString();

          if (endTimeStr.contains(':')) {
            endHour = int.tryParse(endTimeStr.split(':')[0]);
          }
        }

        // 시간 정보가 추출되지 않았다면 기본값
        startHour ??= 9;
        endHour ??= startHour + 1;

        // 시간대 차지 표시
        for (int h = startHour; h <= endHour; h++) {
          occupiedHours.add(h);
        }

        schedule.add({
          'id': 'cal_${schedule.length}',
          'title': '(일정) ${event['title']}',
          'time': event['startTime'],
          'endTime': event['endTime'] ??
              '${(startHour + 1).toString().padLeft(2, '0')}:00',
          'priority': 3, // 최우선
          'description': '캘린더 일정',
          'memo': '',
          'location': event['location'] ?? '',
        });
      }
    }

    // 작업 중요도/긴급도 기준 정렬
    tasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore); // 높은 점수가 먼저 오도록
    });

    // 남은 시간대에 작업 배치
    int taskStartHour = 9; // 기본 시작 시간

    for (var task in tasks) {
      // 기존 task에 이미 시간이 있으면 해당 시간 사용
      String? taskTime = task['time'];
      String? taskEndTime = task['endTime'];
      int? taskTimeHour;

      if (taskTime != null && taskTime.isNotEmpty) {
        // AM/PM 형식인 경우
        if (taskTime.contains('AM') || taskTime.contains('PM')) {
          final parts = taskTime.split(' ');
          if (parts.length >= 2 && parts[1].contains(':')) {
            final timeParts = parts[1].split(':');
            int hour = int.tryParse(timeParts[0]) ?? 0;

            // PM이고 12시가 아니면 12 더하기
            if (parts[0] == 'PM' && hour < 12) {
              hour += 12;
            }
            // AM이고 12시면 0시로
            else if (parts[0] == 'AM' && hour == 12) {
              hour = 0;
            }

            taskTimeHour = hour;
          }
        }
        // HH:MM 형식인 경우
        else if (taskTime.contains(':')) {
          taskTimeHour = int.tryParse(taskTime.split(':')[0]);
        }
      }

      // 시간 정보가 있으면 해당 시간 사용, 없으면 가용 시간대 찾기
      if (taskTimeHour != null) {
        taskStartHour = taskTimeHour;
      } else {
        // 사용 가능한 시간 찾기
        while (occupiedHours.contains(taskStartHour)) {
          taskStartHour++;
          if (taskStartHour >= 21) break; // 최대 오후 9시까지
        }
      }

      if (taskStartHour >= 21) break;

      // 중요도/긴급도에 따른 우선순위 설정
      final importance = task['importance'] ?? 1;
      final urgency = task['urgency'] ?? 1;
      final priority = importance > urgency ? importance : urgency;

      // 기존 시간 형식 유지
      final String timeStr = taskTime ??
          '${taskStartHour.toString().padLeft(2, '0')}:00';
      final String endTimeStr = taskEndTime ??
          '${(taskStartHour + 1).toString().padLeft(2, '0')}:00';

      schedule.add({
        'id': 'task_${schedule.length}',
        'title': task['title'],
        'time': timeStr,
        'endTime': endTimeStr,
        'priority': priority,
        'description': '중요도: $importance, 긴급도: $urgency',
        'memo': '',
        'location': '',
        'dueDate': task['dueDate'],
      });

      occupiedHours.add(taskStartHour);
      taskStartHour++;
    }

    // 시간순 정렬
    schedule.sort((a, b) {
      if (a['time'] == null) return 1;
      if (b['time'] == null) return -1;

      // HH:MM 형식으로 통일하여 비교
      String timeA = a['time'];
      String timeB = b['time'];

      // AM/PM 형식인 경우 HH:MM으로 변환
      if (timeA.contains('AM') || timeA.contains('PM')) {
        final parts = timeA.split(' ');
        if (parts.length >= 2) {
          timeA = _convertAmPmToHHMM(parts[0], parts[1]);
        }
      }

      if (timeB.contains('AM') || timeB.contains('PM')) {
        final parts = timeB.split(' ');
        if (parts.length >= 2) {
          timeB = _convertAmPmToHHMM(parts[0], parts[1]);
        }
      }

      return timeA.compareTo(timeB);
    });

    return schedule;
  }

// AM/PM 형식을 HH:MM으로 변환하는 헬퍼 메서드
  String _convertAmPmToHHMM(String amPm, String timeStr) {
    if (!timeStr.contains(':')) return timeStr;

    final parts = timeStr.split(':');
    if (parts.length != 2) return timeStr;

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;

    if (amPm == 'PM' && hour < 12) {
      hour += 12;
    } else if (amPm == 'AM' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(
        2, '0')}';
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

  String _getWeekdayString(int weekday) {
    switch (weekday) {
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
