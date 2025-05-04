import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';


// API URL (Flask 서버 URL)
final String apiUrl = 'http://localhost:5000';  // 로컬 개발 환경에서 사용할 경우

// TaskDataService 클래스
class TaskDataService {
  static final TaskDataService _instance = TaskDataService._internal();

  factory TaskDataService() {
    return _instance;
  }

  TaskDataService._internal();

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

  // Todo List 추가 메서드
  void addTodoTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }
    if (!todoTasksByDate[dateKey]!.any((existingTask) =>
    isSameDate(existingTask.date, task.date) &&
        existingTask.title == task.title)) {
      todoTasksByDate[dateKey]!.add(task);
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
  }

  void removeTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }
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
      bottomNavigationBar: BottomNav(initialIndex: 0, userId: widget.userId),
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

// ✅ 이 파일은 DailyPlannerPage.dart 기준으로, 시간 24시간제 표기 및 시간/일정박스 가로 정렬 수정 버전입니다.

  String _format24FromTimeString(String time) {
    final match = RegExp(r'(AM|PM)\s(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return time;

    String period = match.group(1)!;
    int hour = int.parse(match.group(2)!);
    String minute = match.group(3)!;

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  Widget _buildPlannerView() {
    final tasks = _taskDataService.getPlannerTasksForDate(selectedDate);

    // 시간 순 정렬
    tasks.sort((a, b) {
      DateTime? timeA = _parseTimeToDateTime(a.time);
      DateTime? timeB = _parseTimeToDateTime(b.time);
      return (timeA ?? DateTime(0)).compareTo(timeB ?? DateTime(0));
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy-MM-dd').format(selectedDate),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    final dateKey = _taskDataService.dateToKey(selectedDate);
                    _taskDataService.plannerTasksByDate.remove(dateKey);
                  });
                },
                child: const Text('🗑️', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
        ListView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final startTime = _format24FromTimeString(task.time ?? '');
            final endTime = _format24FromTimeString(task.endTime ?? '');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 시간 표시
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (startTime.isNotEmpty)
                        Text(
                          startTime,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 40),
                      if (endTime.isNotEmpty)
                        Text(
                          endTime,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 오른쪽 일정박스
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: task.color ?? _getFixedColorForTask(task.title), // ✅ 고정 색상 적용
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: 1.2,
                                child: Checkbox(
                                  value: task.isCompleted,
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
                          if (task.memo != null && task.memo!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                task.memo!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          if (task.location != null && task.location!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.location!,
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }



  DateTime? _parseTimeToDateTime(String? time) {
    if (time == null) return null;
    final match = RegExp(r'(AM|PM)\s(\d{1,2}):(\d{2})').firstMatch(time);
    if (match == null) return null;

    String period = match.group(1)!;
    int hour = int.parse(match.group(2)!);
    String? minuteString = match.group(3);

    if (minuteString == null) return null; // minute가 null일 경우 처리

    int minute = int.tryParse(minuteString) ?? 0; // minute가 null이거나 숫자가 아닌 경우 기본값 0을 설정

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return DateTime(0, 1, 1, hour, minute);
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