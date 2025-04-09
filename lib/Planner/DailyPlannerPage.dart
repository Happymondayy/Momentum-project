import 'package:flutter/material.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';

// Shared data service to manage tasks and their state
class TaskDataService {
  static final TaskDataService _instance = TaskDataService._internal();

  factory TaskDataService() {
    return _instance;
  }

  TaskDataService._internal();

  // Using Todo_Task from todo_list_screen.dart for consistency
  final Map<String, List<Todo_Task>> tasksByDate = {};

  String dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Todo_Task> getTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return tasksByDate[dateKey] ?? [];
  }

  void addTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (tasksByDate.containsKey(dateKey)) {
      tasksByDate[dateKey]!.add(task);
    } else {
      tasksByDate[dateKey] = [task];
    }
  }

  double calculateProgressForDate(DateTime date) {
    final tasks = getTasksForDate(date);
    if (tasks.isEmpty) {
      return 0.0;
    }

    int completedTasks = tasks.where((task) => task.isCompleted).length;
    return (completedTasks / tasks.length) * 100;
  }
}

// DailyPlannerPage class definition
class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
  TodoListScreenState? todoListScreenState;
  final TaskDataService _taskDataService = TaskDataService(); // 변경된 클래스 이름
  double progressPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    updateProgress();
  }

  void updateProgress() {
    setState(() {
      progressPercentage = _taskDataService.calculateProgressForDate(selectedDate);
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
            MonthSelector(
              selectedDate: selectedDate,
              onMonthChanged: (newDate) {
                setState(() {
                  selectedDate = newDate;
                  updateProgress();
                });
              },
            ),

            // Weekly Calendar
            WeeklyCalendar(
              selectedDate: selectedDate,
              onDateSelected: changeSelectedDate,
            ),

            // Progress Section - Using the component from TodoList
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProgressScreen(
                tasks: _taskDataService.getTasksForDate(selectedDate),
                progressPercentage: progressPercentage,
              ),
            ),

            // Header with toggle
            _buildHeaderWithToggle(),

            // Content area
            Expanded(
              child: isPlannerView
                  ? (_taskDataService.getTasksForDate(selectedDate).isEmpty
                  ? const EmptyStateWidget()
                  : _buildPlannerView())
                  : TodoListScreen(
                isEmbedded: true,
                initialDate: selectedDate,
                onStateCreated: (state) {
                  todoListScreenState = state;
                },
                onTaskStatusChanged: () {
                  updateProgress();
                },
                taskDataService: _taskDataService, // 변경된 클래스 사용
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
    final tasks = _taskDataService.getTasksForDate(selectedDate);

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
                                    task.isCompleted = value ?? false;
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
                        if (task.location != null && task.location!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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

  void _generateAIPlanner() {
    // Demo data generation
    final generatedTasks = [
      Todo_Task(
        title: "아침 운동",
        date: selectedDate,
        time: "07:00",
        importance: 2,
        urgency: 1,
        isImportant: false,
        isUrgent: false,
      ),
      Todo_Task(
        title: "팀 미팅",
        date: selectedDate,
        time: "10:00",
        importance: 3,
        urgency: 2,
        isImportant: true,
        isUrgent: false,
      ),
    ];

    // Add generated tasks to data service
    for (var task in generatedTasks) {
      _taskDataService.addTask(task);
    }

    // Update UI
    setState(() {
      updateProgress();
    });
  }
}