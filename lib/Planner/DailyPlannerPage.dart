import 'package:flutter/material.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import 'task_list_screen.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';

// Task 클래스 정의
class Task {
  String title;
  DateTime date;
  String? time;
  bool isCompleted;
  bool isImportant;
  bool isUrgent;
  String? memo;
  String? location;
  int importance;
  int urgency;

  Task({
    required this.title,
    required this.date,
    this.time,
    this.isCompleted = false,
    this.isImportant = false,
    this.isUrgent = false,
    this.memo,
    this.location,
    this.importance = 1,
    this.urgency = 1,
  });
}

// 월 선택기 위젯
class planner_MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onMonthChanged;

  const planner_MonthSelector({
    Key? key,
    required this.selectedDate,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              final previousMonth = DateTime(
                selectedDate.year,
                selectedDate.month - 1,
                selectedDate.day,
              );
              onMonthChanged(previousMonth);
            },
            child: const Icon(Icons.chevron_left, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Text(
            '${selectedDate.year}년 ${selectedDate.month}월',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              final nextMonth = DateTime(
                selectedDate.year,
                selectedDate.month + 1,
                selectedDate.day,
              );
              onMonthChanged(nextMonth);
            },
            child: const Icon(Icons.chevron_right, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

// 주간 캘린더 위젯
class planner_WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const planner_WeeklyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  List<DateTime> _getDaysInWeek(DateTime date) {
    final DateTime firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => firstDayOfWeek.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getDaysInWeek(selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: weekDays.map((day) {
          final isSelected = day.day == selectedDate.day &&
              day.month == selectedDate.month &&
              day.year == selectedDate.year;
          final isToday = day.day == DateTime.now().day &&
              day.month == DateTime.now().month &&
              day.year == DateTime.now().year;

          return InkWell(
            onTap: () => onDateSelected(day),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE2DBFE)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayName(day.weekday),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDayName(int weekday) {
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
}

// 진행률 화면
class planner_ProgressScreen extends StatelessWidget {
  final List<Task> tasks;
  final double progressPercentage;

  const planner_ProgressScreen({
    Key? key,
    required this.tasks,
    required this.progressPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalTasks = tasks.length;
    int completedTasks = tasks.where((task) => task.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFE8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Your Progress Now',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              )
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedTasks/$totalTasks Task Complete',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
              Text(
                '${progressPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF9D8CFF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 플래너 생성 중 화면
class PlannerGeneratingScreen extends StatelessWidget {
  const PlannerGeneratingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
  }
}

// DailyPlannerPage 클래스 정의
class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isPlannerView = true; // true for planner, false for todo list
  TodoListScreenState? todoListScreenState; // Reference to TodoListScreen state
  DateTime selectedDate = DateTime.now();
  double progressPercentage = 0.0;
  Map<String, List<Task>> tasksByDate = {}; // Task로 변경된 부분

  @override
  void initState() {
    super.initState();
    calculateProgress(); // 초기 진행률 계산
  }

  void changeSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      calculateProgress();
    });
  }

  void calculateProgress() {
    final tasks = getTasksForSelectedDate();
    if (tasks.isEmpty) {
      setState(() {
        progressPercentage = 0.0;
      });
      return;
    }

    int completedTasks = tasks.where((task) => task.isCompleted).length;
    setState(() {
      progressPercentage = (completedTasks / tasks.length) * 100;
    });
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Task> getTasksForSelectedDate() {
    final dateKey = _dateToKey(selectedDate);
    return tasksByDate[dateKey] ?? [];
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
            if (isPlannerView) ...[ // 플래너 뷰일 때만 캘린더와 진행률 표시
              planner_MonthSelector(
                selectedDate: selectedDate,
                onMonthChanged: (newDate) {
                  setState(() {
                    selectedDate = newDate;
                    calculateProgress();
                  });
                },
              ),
              planner_WeeklyCalendar(
                selectedDate: selectedDate,
                onDateSelected: changeSelectedDate,
              ),
              planner_ProgressScreen(
                tasks: getTasksForSelectedDate(),
                progressPercentage: progressPercentage,
              ),
            ],
            _buildHeaderWithToggle(),
            Expanded(
              child: isPlannerView
                  ? (getTasksForSelectedDate().isEmpty
                  ? const EmptyStateWidget()
                  : const TaskListScreen())
                  : TodoListScreen(
                isEmbedded: true,
                initialDate: selectedDate,
                onStateCreated: (state) {
                  todoListScreenState = state;
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNav(),
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
              setState(() => isPlannerView = value);
            },
            activeTrackColor: const Color(0xFFD7D0FF),
            activeColor: const Color(0xFF9D8CFF),
          ),
        ],
      ),
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
        return const PlannerGeneratingScreen();
      },
    );

    // AI 플래너 생성 프로세스 시뮬레이션
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      _generateAIPlanner(); // AI 플래너 생성 함수 호출
    });
  }

  void _generateAIPlanner() {
    // TODO: 실제 AI 플래너 생성 로직 구현
    // 1. 투두리스트 데이터 가져오기
    // 2. 캘린더 일정 데이터 가져오기
    // 3. AI 모델을 통한 플래너 생성
    // 4. 생성된 플래너 표시

    // 임시 데모 데이터
    final generatedTasks = [
      Task(
        title: "아침 운동",
        date: selectedDate,
        time: "07:00",
        importance: 2,
        urgency: 1,
      ),
      Task(
        title: "팀 미팅",
        date: selectedDate,
        time: "10:00",
        importance: 3,
        urgency: 2,
      ),
      // 추가적인 작업을 여기에 추가할 수 있습니다.
    ];

    // 생성된 작업을 tasksByDate에 추가
    final dateKey = _dateToKey(selectedDate);
    tasksByDate[dateKey] = generatedTasks;

    // 진행률 계산
    calculateProgress();
  }
}