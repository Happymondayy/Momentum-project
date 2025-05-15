import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
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

// loadTasksFromFirestore 함수 수정
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

        final task = Todo_Task(
          title: data['title'],
          description: data['description'],
          time: data['time'],
          endTime: data['endTime'],
          date: dateTime,
          isImportant: data['isImportant'] ?? false,
          isUrgent: data['isUrgent'] ?? false,
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
          isUrgent: data['isUrgent'] ?? false,
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
        'isUrgent': task.isUrgent,
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
        'isUrgent': task.isUrgent,
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

  // Todo List 조회 메서드
  List<Todo_Task> getTodoTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return todoTasksByDate[dateKey]?.where((task) =>
        isSameDate(task.date, date)).toList() ?? [];
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
  const DailyPlannerPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}



class _DailyPlannerPageState extends State<DailyPlannerPage> {
  late String userId; // 나중에 초기화할 변수

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    userId = args?['userId'] ?? '';
    print('📌 userId 받은 값: $userId');
  }

  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
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

    return SingleChildScrollView(
      child: Column(
        children: [
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 일정 전체 삭제 버튼
                IconButton(
                  onPressed: () {
                    // 확인 대화상자 표시
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
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

          // 시간별 일정 목록
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
                  color: isCurrentHour ? Colors.purple.withOpacity(0.05) : null, // 보라색으로 변경
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
                              fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentHour ? Colors.purple.shade700 : Colors.grey.shade600, // 보라색으로 변경
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
                            children: hourTasks.map((task) => _buildTodoTaskCard(task)).toList(),
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
      final dueDay = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      final difference = dueDay.difference(DateTime(today.year, today.month, today.day)).inDays;
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
          color: isCompleted ? Colors.grey.shade300 : taskColor.withOpacity(0.5),
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
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                            _taskDataService.updateTaskStatus(task, value ?? false);
                            updateProgress();
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 메모와 위치 정보 (가로로 배치)
                if (task.memo != null && task.memo!.isNotEmpty || task.location != null && task.location!.isNotEmpty)
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
                                color: isCompleted ? Colors.grey : Colors.black87,
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
                                color: isCompleted ? Colors.grey : Colors.purple, // 보라색으로 변경
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.location!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isCompleted ? Colors.grey : Colors.purple, // 보라색으로 변경
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          dueStatus ?? DateFormat('MM/dd').format(task.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: daysLeft != null && daysLeft <= 1 ? FontWeight.bold : FontWeight.normal,
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

  void _generateAIPlanner() async {
    final List<Todo_Task> todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);

    // Firebase에서 Calendar Event 가져오기
    final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
    List<Todo_Task> calendarTasks = [];
    List<Map<String, int>> occupiedTimes = []; // 예약된 시간 슬롯 저장

    for (var doc in eventsSnapshot.docs) {
      final data = doc.data();
      final startDate = DateTime.parse(data['startDate']);

      if (startDate.year == selectedDate.year &&
          startDate.month == selectedDate.month &&
          startDate.day == selectedDate.day) {
        if (data['startTime'] != null) {
          int hour = data['startTime']['hour'];
          int minute = data['startTime']['minute'];
          occupiedTimes.add({'hour': hour, 'minute': minute});
        }

        calendarTasks.add(
          Todo_Task(
            title: data['title'],
            date: selectedDate,
            time: data['startTime'] != null
                ? '${data['startTime']['hour'].toString().padLeft(2, '0')}:${data['startTime']['minute'].toString().padLeft(2, '0')}'
                : null,
            isImportant: true,
            isUrgent: false,
            importance: 3,
            urgency: 2,
          ),
        );
      }
    }

    final allTasks = [...todoTasks, ...calendarTasks];

    if (allTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오늘 생성할 투두/일정이 없습니다!')),
      );
      return;
    }

    // API에서 우선순위 가져오기
    Map<String, int> priorities = await _getPriorityFromAI(allTasks);

    // 우선순위 정렬
    allTasks.sort((a, b) {
      int aPriority = priorities[a.title] ?? 0;
      int bPriority = priorities[b.title] ?? 0;
      return bPriority.compareTo(aPriority);
    });

    // 시간 슬롯 매핑 시작
    int currentHour = 9; // 오전 9시부터 시작 (기본값 수정)
    int currentMinute = 0;

    // 기존의 플래너 태스크 초기화 (추가)
    final dateKey = _taskDataService.dateToKey(selectedDate);
    _taskDataService.plannerTasksByDate[dateKey] = [];

    for (var task in allTasks) {
      // 이미 시간이 있는 작업은 건너뛰기
      if (task.time != null && task.time!.isNotEmpty) {
        _taskDataService.addPlannerTask(task); // 이미 시간이 있는 작업도 추가 (추가)
        continue;
      }

      bool isUrgentTask = task.isUrgent || (task.urgency != null && task.urgency >= 4);
      bool taskScheduled = false; // 태스크가 스케줄링됐는지 확인 (추가)

      while (currentHour < 24 && !taskScheduled) { // 조건 추가 (수정)
        // 현재 시간 슬롯이 비어있는지 확인
        if (!_isSlotOccupied(currentHour, currentMinute, occupiedTimes)) {
          // 슬롯 배정
          task.time =
          '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';

          // 예약된 시간 기록
          occupiedTimes.add({'hour': currentHour, 'minute': currentMinute});

          // 긴급한 작업은 30분 차지, 보통 작업은 1시간 차지
          if (isUrgentTask) {
            final nextTime = _advanceTime(currentHour, currentMinute, 30);
            currentHour = nextTime['hour']!;
            currentMinute = nextTime['minute']!;
          } else {
            final nextTime = _advanceTime(currentHour, currentMinute, 60);
            currentHour = nextTime['hour']!;
            currentMinute = nextTime['minute']!;
          }

          _taskDataService.addPlannerTask(task);
          taskScheduled = true; // 태스크를 스케줄링 완료로 표시 (추가)

        } else {
          // 슬롯이 차있으면 30분 후로 이동
          final nextTime = _advanceTime(currentHour, currentMinute, 30);
          currentHour = nextTime['hour']!;
          currentMinute = nextTime['minute']!;
        }
      }
    }

    // 전체 UI 갱신 (수정)
    setState(() {
      updateProgress();
      // 강제로 빌더를 다시 호출하도록 isPlannerView를 재설정
      isPlannerView = false;
      isPlannerView = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI 플래너가 생성되었습니다!')),
    );
  }

  // AI 모델에서 우선순위 계산 API 호출
  Future<Map<String, int>> _getPriorityFromAI(List<Todo_Task> allTasks) async {
    try {
      final List<Map<String, dynamic>> tasksData = allTasks.map((task) {
        return {
          'title': task.title,
          'importance': task.importance,
          'urgency': task.urgency,
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$apiUrl/priority'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'tasks': tasksData}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        Map<String, int> priorityList = {};
        for (var task in responseData['tasks']) {
          priorityList[task['title']] = task['priority'];
        }
        return priorityList;
      } else {
        throw Exception('Failed to load priority');
      }
    } catch (e) {
      print("Error fetching priority data: $e");
      return {};
    }
  }

  // 시간 전진 함수
  Map<String, int> _advanceTime(int currentHour, int currentMinute, int minutes) {
    currentMinute += minutes;
    while (currentMinute >= 60) {
      currentMinute -= 60;
      currentHour += 1;
    }
    if (currentHour >= 24) {
      currentHour = 0;
    }
    return {'hour': currentHour, 'minute': currentMinute};
  }

  // 슬롯이 이미 예약됐는지 확인
  bool _isSlotOccupied(int hour, int minute, List<Map<String, int>> occupied) {
    return occupied.any((slot) =>
    slot['hour'] == hour && slot['minute'] == minute);
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
