import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';


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
    // dateKey로 찾은 목록에서 날짜가 정확히 일치하는 항목만 필터링
    return todoTasksByDate[dateKey]?.where((task) =>
        isSameDate(task.date, date)).toList() ?? [];
  }

// Todo List 추가 메서드
  void addTodoTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }

    // 중복 체크 후 추가
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

    // Todo에서 제거
    if (todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }

    // Planner에서 제거 (플래너에서도 삭제될 수 있도록)
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }
  }


  // 진행률 계산 (Todo List와 Planner 각각에 대해)
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

    // Todo List에서 해당 태스크 찾아 업데이트
    if (todoTasksByDate.containsKey(dateKey)) {
      try {
        final todoTask = todoTasksByDate[dateKey]!
            .firstWhere((t) => t.title == task.title);
        todoTask.isCompleted = isCompleted;
      } catch (e) {
        // 태스크를 못 찾은 경우 무시
      }
    }

    // Planner에서 해당 태스크 찾아 업데이트
    if (plannerTasksByDate.containsKey(dateKey)) {
      try {
        final plannerTask = plannerTasksByDate[dateKey]!
            .firstWhere((t) => t.title == task.title);
        plannerTask.isCompleted = isCompleted;
      } catch (e) {
        // 태스크를 못 찾은 경우 무시
      }
    }
  }

}

// DailyPlannerPage 클래스
class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
  TodoListScreenState? todoListScreenState;
  final TaskDataService _taskDataService = TaskDataService();
  double progressPercentage = 0.0;

  @override
  void initState() {
    super.initState();
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

            // Progress Section - Using the component from TodoList
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
      bottomNavigationBar: BottomNav(initialIndex: 1),
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
                ? 'My Today Tasks'
                : 'Tasks for ${selectedDate.month}/${selectedDate.day}')
                : 'My Todo List',
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final timeString = task.time ?? "00:00";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side time display
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 16),

              // Task card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: getBrightPastelColor(),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                    _taskDataService.updateTaskStatus(
                                        task, value ?? false);
                                    updateProgress();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (task.memo != null && task.memo!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            task.memo!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF0484444),
                            ),
                          ),
                        ],
                        if (task.location != null &&
                            task.location!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16,
                                  color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                task.location!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

    // 우선순위 정렬
    allTasks.sort((a, b) {
      int aScore = _calculatePriorityScore(a);
      int bScore = _calculatePriorityScore(b);
      return bScore.compareTo(aScore);
    });

    // 시간 슬롯 매핑 시작
    int currentHour = 0;
    int currentMinute = 0;

    for (var task in allTasks) {
      // 이미 시간이 있는 작업은 건너뛰기
      if (task.time != null && task.time!.isNotEmpty) {
        continue;
      }

      bool isUrgentTask = task.urgency >= 4;

      while (currentHour < 24) {
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
          break;
        } else {
          // 슬롯이 차있으면 30분 후로 이동
          final nextTime = _advanceTime(currentHour, currentMinute, 30);
          currentHour = nextTime['hour']!;
          currentMinute = nextTime['minute']!;
        }
      }

      _taskDataService.addPlannerTask(task);
    }

    setState(() {
      updateProgress();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI 플래너가 생성되었습니다!')),
    );
  }

// 시간 전진 함수
  Map<String, int> _advanceTime(int currentHour, int currentMinute, int minutes) {
    currentMinute += minutes;
    while (currentMinute >= 60) {
      currentMinute -= 60;
      currentHour += 1;
    }
    if (currentHour >= 24) {
      currentHour = 0; // 24시간 넘으면 0으로
    }
    return {'hour': currentHour, 'minute': currentMinute};
  }

// 우선순위 점수 계산
  int _calculatePriorityScore(Todo_Task task) {
    int baseScore = (task.importance * 2) + (task.urgency * 2);

    final now = DateTime.now();
    final daysUntilDeadline = task.date
        .difference(now)
        .inDays;

    if (daysUntilDeadline <= 1) {
      baseScore += 5;
    } else if (daysUntilDeadline <= 3) {
      baseScore += 3;
    } else if (daysUntilDeadline <= 7) {
      baseScore += 1;
    }

    return baseScore;
  }

// 슬롯이 이미 예약됐는지 확인
  bool _isSlotOccupied(int hour, int minute, List<Map<String, int>> occupied) {
    return occupied.any((slot) =>
    slot['hour'] == hour && slot['minute'] == minute);
  }

}

// 개선된 월 선택기 위젯 - 화살표로 이전/다음 달 이동
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
          // Previous month button
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              // Go to previous month
              final newDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),

          // Current month and year display
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

          // Next month button
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () {
              // Go to next month
              final newDate = DateTime(selectedDate.year, selectedDate.month + 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    // Show month-year picker dialog
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

// 개선된 주간 캘린더 위젯 (스크롤 기능 강화)
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
  final int _totalWeeks = 100; // 충분히 많은 주를 표시
  late DateTime _baseDate;
  late DateTime _currentStartDate;

  @override
  void initState() {
    super.initState();
    // Set base date to first day of current week, 50 weeks ago
    _baseDate = _findFirstDayOfWeek(DateTime.now().subtract(Duration(days: 50 * 7)));
    _currentPage = _getPageForDate(widget.selectedDate);
    _pageController = PageController(initialPage: _currentPage);
    _currentStartDate = _getStartDateForPage(_currentPage);
  }

  @override
  void didUpdateWidget(EnhancedWeeklyCalendar oldWidget) {
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

  // Find the first day (Monday) of the week containing the given date
  DateTime _findFirstDayOfWeek(DateTime date) {
    // Subtract weekday - 1 days to get to Monday (weekday 1)
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // Get the page number for a given date
  int _getPageForDate(DateTime date) {
    final firstDayOfWeek = _findFirstDayOfWeek(date);
    final diffDays = firstDayOfWeek.difference(_baseDate).inDays;
    return (diffDays / 7).round();
  }

  // Get the start date for a given page
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
        // 요일 표시 행
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
        // 날짜 표시 행
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