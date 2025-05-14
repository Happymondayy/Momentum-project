import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../Planner/DailyPlannerPage.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'package:collection/collection.dart';

class Todo_Task {
  String id; // Firestore 문서 ID를 저장할 필드 추가
  String title; // 제목
  String? description;
  String? time;
  String? endTime;
  DateTime date;
  bool isImportant;
  bool isUrgent;
  String? memo;
  String? location;
  int importance;
  int urgency;
  Color? color;
  DateTime? dueDate;
  bool isCompleted;
  int? notificationId;
  List<int>? reminderMinutesBefore; // 알림을 몇 분 전에 울릴지

  Todo_Task({
    this.id = '', // 기본값 빈 문자열
    required this.title,
    this.description,
    this.time,
    this.endTime,
    required this.date,
    required this.isImportant,
    required this.isUrgent,
    this.memo,
    this.location,
    required this.importance,
    required this.urgency,
    this.isCompleted = false,
    this.color,
    this.dueDate,
    this.notificationId,
    this.reminderMinutesBefore,
  });

  // Firestore 문서를 Todo_Task 객체로 변환하는 팩토리 생성자
  factory Todo_Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Color 객체는 Firestore에 직접 저장할 수 없으므로 정수값으로 변환하여 저장
    Color? taskColor;
    if (data['color'] != null) {
      taskColor = Color(data['color']);
    }

    return Todo_Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      time: data['time'],
      endTime: data['endTime'],
      date: (data['date'] as Timestamp).toDate(),
      isImportant: data['isImportant'] ?? false,
      isUrgent: data['isUrgent'] ?? false,
      memo: data['memo'],
      location: data['location'],
      importance: data['importance'] ?? 1,
      urgency: data['urgency'] ?? 1,
      isCompleted: data['isCompleted'] ?? false,
      color: taskColor,
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      notificationId: data['notificationId'],
      reminderMinutesBefore: List<int>.from(data['reminderMinutesBefore'] ?? []),
    );
  }

  // Todo_Task 객체를 Firestore 문서로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'time': time,
      'endTime': endTime,
      'date': Timestamp.fromDate(date),
      'isImportant': isImportant,
      'isUrgent': isUrgent,
      'memo': memo,
      'location': location,
      'importance': importance,
      'urgency': urgency,
      'isCompleted': isCompleted,
      'color': color?.value, // Color 객체를 정수값으로 변환
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'notificationId': notificationId,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }
}

// 진행률 화면 위젯
class ProgressScreen extends StatelessWidget {
  final List<Todo_Task> tasks;
  final double progressPercentage;

  const ProgressScreen({
    Key? key,
    required this.tasks,
    required this.progressPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalTasks = tasks.length;
    int completedTasks = tasks.where((task) => task.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
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
        children: [
          const Text('Your Progress Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildProgressBar(context, progressPercentage, completedTasks, totalTasks),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progressPercentage, int completedTasks, int totalTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
                  ),
                  Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * (progressPercentage / 100) * 0.7,
                    decoration: BoxDecoration(
                      color: progressPercentage == 100 ? Colors.green : const Color(0xFFECDBF9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Text('${progressPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Text('$completedTasks/$totalTasks Task Complete', style: const TextStyle(fontSize: 13, color: Colors.black)),
      ],
    );
  }
}

// 월 선택기 위젯
class MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onMonthChanged;

  const MonthSelector({
    Key? key,
    required this.selectedDate,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMonthPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${selectedDate.year}년 ${selectedDate.month}월',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context) {
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

// 주간 캘린더 위젯
class WeeklyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WeeklyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  _WeeklyCalendarState createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  late PageController _pageController;
  late DateTime _displayedWeekStart;
  int _currentPage = 0;


  @override
  void initState() {
    super.initState();
    _initCalendar();
  }

  void _initCalendar() {
    _displayedWeekStart = _findFirstDayOfWeek(widget.selectedDate);
    _pageController = PageController(initialPage: _currentPage);
  }

  DateTime _findFirstDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
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
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () {
                  _pageController.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
              Text('${_displayedWeekStart.month}월', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                  _displayedWeekStart = _findFirstDayOfWeek(
                    widget.selectedDate.add(Duration(days: 7 * (page - _currentPage))),
                  );
                });
              },
              itemBuilder: (context, pageIndex) {
                final weekStart = _findFirstDayOfWeek(
                  widget.selectedDate.add(Duration(days: 7 * (pageIndex - _currentPage))),
                );
                return _buildWeek(weekStart);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeek(DateTime weekStart) {
    final tasksDataService = TaskDataService();

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
            final isSelected = currentDate.year == widget.selectedDate.year &&
                currentDate.month == widget.selectedDate.month &&
                currentDate.day == widget.selectedDate.day;

            final hasTasks = tasksDataService.getTodoTasksForDate(currentDate).isNotEmpty;

            return Column(
              children: [
                GestureDetector(
                  onTap: () => widget.onDateSelected(currentDate),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: isSelected
                        ? BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.2))
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasTasks)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// TodoList 화면 위젯
class TodoListScreen extends StatefulWidget {
  final DateTime? initialDate;
  final bool isEmbedded;
  final Function(TodoListScreenState)? onStateCreated;
  final Function()? onTaskStatusChanged;
  final dynamic taskDataService;

  const TodoListScreen({
    Key? key,
    this.initialDate,
    this.isEmbedded = false,
    this.onStateCreated,
    this.onTaskStatusChanged,
    this.taskDataService,
  }) : super(key: key);

  @override
  TodoListScreenState createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  DateTime? selectedDueDate;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController memoController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  @override
  void dispose() {
  titleController.dispose();
  memoController.dispose();
  locationController.dispose();
  super.dispose();
  }

  late DateTime selectedDate;
  double progressPercentage = 0.0;
  late dynamic _taskDataService;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    _taskDataService = widget.taskDataService ?? TaskDataService();
    _notificationService.init();

    if (widget.onStateCreated != null) {
      widget.onStateCreated!(this);
    }

    calculateProgress();
  }

  List<Todo_Task> getTasksForSelectedDate() {
    return _taskDataService.getTodoTasksForDate(selectedDate);
  }

  void changeSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      calculateProgress();
    });
  }

  void calculateProgress() {
    setState(() {
      progressPercentage = _taskDataService.calculateCombinedProgressForDate(selectedDate);
    });
  }

  void _scheduleNotificationsForTask(Todo_Task task) {
    if (!task.isImportant) return;

    final notificationId = task.notificationId ?? DateTime.now().millisecondsSinceEpoch % 100000;
    task.notificationId = notificationId;

    // ✅ 시작 시간 있는 경우에만 알림 설정
    if (task.time != null && task.time!.isNotEmpty && task.reminderMinutesBefore != null) {
      final startDateTime = _parseTimeToDateTime(task.time, task.date); // ✅ 이거 추가하면 에러 해결됨

      for (final minute in task.reminderMinutesBefore!) {
        final scheduledTime = startDateTime.subtract(Duration(minutes: minute));
        if (scheduledTime.isAfter(DateTime.now())) {
          _notificationService.scheduleCustomReminderNotification(
            notificationId + minute,
            task.title,
            scheduledTime,
            minute,
          );
        }
      }
    }

    // ✅ 마감일 알림은 그대로 유지
    if (task.dueDate != null) {
      _notificationService.scheduleDeadlineNotification(
        notificationId,
        task.title,
        task.dueDate!,
      );
    }
  }


  // 날짜 선택 헤더 위젯
  Widget _buildDateHeader() {
    return Column(
      children: [
        MonthSelector(
          selectedDate: selectedDate,
          onMonthChanged: (newDate) {
            setState(() {
              selectedDate = newDate;
              calculateProgress();
            });
          },
        ),
        WeeklyCalendar(
          selectedDate: selectedDate,
          onDateSelected: changeSelectedDate,
        ),
      ],
    );
  }

  // 진행률 섹션 위젯
  Widget _buildProgressSection(List<Todo_Task> tasks) {
    return ProgressScreen(
      tasks: tasks,
      progressPercentage: progressPercentage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksForSelectedDate = getTasksForSelectedDate();

    if (widget.isEmbedded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: tasksForSelectedDate.isEmpty
            ? _buildEmptyState('오늘 할 일이 없습니다')
            : ListView.builder(
          itemCount: tasksForSelectedDate.length,
          itemBuilder: (context, index) {
            return _buildTaskItem(tasksForSelectedDate[index]);
          },
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Todo List'),
        ),
        body: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateHeader(),
                _buildProgressSection(tasksForSelectedDate),
                const SizedBox(height: 10),
                _buildTodoSectionHeader(
                  isSameDay(selectedDate, DateTime.now())
                      ? 'My Today Tasks'
                      : 'Tasks for ${selectedDate.month}/${selectedDate.day}',
                ),
                _buildTodoList(context, tasks: tasksForSelectedDate),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showAddTaskDialog(context);
          },
          backgroundColor: const Color(0xFF9D8CFF),
          child: const Icon(Icons.add),
        ),
      );
    }
  }

  Widget _buildTodoSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTodoList(BuildContext context, {required List<Todo_Task> tasks}) {
    if (tasks.isEmpty) {
      return _buildEmptyState('오늘 할 일이 없습니다');
    }

    return Column(
      children: tasks.map((task) {
        return _buildTaskItem(task);
      }).toList(),
    );
  }

  Color _getFixedColorForTask(String title) {
    final colors = [
      Colors.purple.shade100,
      Colors.green.shade100,
      Colors.blue.shade100,
      Colors.orange.shade100,
      Colors.red.shade100,
      Colors.teal.shade100,
    ];
    return colors[title.hashCode % colors.length];
  }

  String _buildTimeRange(Todo_Task task) {
    final start = task.time ?? '';
    final end = task.endTime ?? '';
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    } else if (start.isNotEmpty) {
      return start;
    } else if (end.isNotEmpty) {
      return end;
    } else {
      return '';
    }
  }

  DateTime _parseTimeToDateTime(String? timeString, DateTime taskDate) {
    if (timeString == null || timeString.isEmpty) {
      return taskDate;
    }

    // Parse "AM 09:30" or "PM 03:45" format
    final isAM = timeString.startsWith('AM');
    final timeParts = timeString.substring(3).split(':');

    if (timeParts.length != 2) return taskDate;

    try {
      int hour = int.parse(timeParts[0].trim());
      int minute = int.parse(timeParts[1].trim());

      // Convert 12-hour format to 24-hour
      if (!isAM && hour < 12) {
        hour += 12;
      }
      // Convert 12 AM to 0 hours
      if (isAM && hour == 12) {
        hour = 0;
      }

      return DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        hour,
        minute,
      );
    } catch (e) {
      print('Error parsing time: $e');
      return taskDate;
    }
  }

  // 1. _buildTaskItem 함수를 수정하여 GestureDetector로 감싸기
  Widget _buildTaskItem(Todo_Task task) {
    return GestureDetector(
      onTap: () {
        showTaskDetailDialog(context, task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _getFixedColorForTask(task.title),
          borderRadius: BorderRadius.circular(16),
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
              // 제목 + 이모지 + 체크박스 + 삭제 아이콘
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (task.isImportant) const Text('🔔'),
                        if (task.isUrgent) const Text('🔁'),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        setState(() {
                          // If task is being marked as completed, cancel notifications
                          if (!task.isCompleted && value == true && task.notificationId != null) {
                            _notificationService.cancelNotification(task.notificationId!);
                            _notificationService.cancelNotification(task.notificationId! + 1000); // Cancel due date notification
                          }
                          task.isCompleted = value ?? false;
                          calculateProgress();
                          if (widget.onTaskStatusChanged != null) {
                            widget.onTaskStatusChanged!();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('삭제 확인'),
                          content: const Text('이 일정을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () {
                                // If task has notifications, cancel them
                                if (task.notificationId != null) {
                                  _notificationService.cancelNotification(task.notificationId!);
                                  _notificationService.cancelNotification(task.notificationId! + 1000); // Cancel due date notification
                                }
                                setState(() {
                                  _taskDataService.removeTask(task);
                                  calculateProgress();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.delete, color: Colors.redAccent, size: 24),
                  ),
                ],
              ),

              // 시작 - 종료 시간
              if ((task.time != null && task.time!.isNotEmpty) || (task.endTime != null && task.endTime!.isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text(
                  _buildTimeRange(task),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],

              // 위치
              if (task.location != null && task.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      task.location!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],

              // 메모
              if (task.memo != null && task.memo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.memo!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // 마감일
              if (task.dueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.deepOrange),
                    const SizedBox(width: 4),
                    Text(
                      '마감일: ${DateFormat('yyyy-MM-dd').format(task.dueDate!)}',
                      style: const TextStyle(fontSize: 14, color: Colors.deepOrange),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void showTaskDetailDialog(BuildContext context, Todo_Task task) {
    final titleController = TextEditingController(text: task.title);
    final memoController = TextEditingController(text: task.memo ?? '');
    final locationController = TextEditingController(text: task.location ?? '');

    TimeOfDay startTime = _parseTimeString(task.time ?? '');
    TimeOfDay endTime = _parseTimeString(task.endTime ?? '');

    DateTime taskDate = task.date;
    DateTime? dueDate = task.dueDate;
    bool isImportant = task.isImportant;
    bool isUrgent = task.isUrgent;
    int importanceLevel = task.importance;
    int urgencyLevel = task.urgency;
    List<int> selectedReminders = List.from(task.reminderMinutesBefore ?? []);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 다이얼로그 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black12)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '일정 상세 정보',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              if (titleController.text.isEmpty) {
                                _showSnackBar(context, '제목을 입력해주세요');
                                return;
                              }

                              final String formattedStart =
                                  '${startTime.period == DayPeriod.am ? 'AM' : 'PM'} ${startTime.hourOfPeriod.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                              final String formattedEnd =
                                  '${endTime.period == DayPeriod.am ? 'AM' : 'PM'} ${endTime.hourOfPeriod.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                              // 변경 감지 후 알림 재설정
                              final hasNotificationChange =
                                  task.isImportant != isImportant ||
                                      task.time != formattedStart ||
                                      task.dueDate != dueDate ||
                                      !const ListEquality().equals(task.reminderMinutesBefore, selectedReminders);

                              if (hasNotificationChange && task.notificationId != null) {
                                _notificationService.cancelNotification(task.notificationId!);
                                _notificationService.cancelNotification(task.notificationId! + 1000);
                              }

                              task.title = titleController.text;
                              task.time = formattedStart;
                              task.endTime = formattedEnd;
                              task.isImportant = isImportant;
                              task.isUrgent = isUrgent;
                              task.memo = memoController.text;
                              task.location = locationController.text;
                              task.importance = importanceLevel;
                              task.urgency = urgencyLevel;
                              task.dueDate = dueDate;
                              task.reminderMinutesBefore = isImportant ? selectedReminders : [];

                              if (isImportant) {
                                _scheduleNotificationsForTask(task);
                              }

                              Navigator.of(context).pop();
                              setState(() {
                                calculateProgress();
                              });

                              if (widget.onTaskStatusChanged != null) {
                                widget.onTaskStatusChanged!();
                              }

                              _showSnackBar(context, '일정이 수정되었습니다');
                            },
                          ),
                        ],
                      ),
                    ),

                    // 폼 영역
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                titleController,
                                '제목',
                                '제목을 입력하세요 (필수)',
                                    (value) {
                                  if (value.isEmpty) {
                                    _showSnackBar(context, '제목을 입력해주세요');
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildDatePicker(context, taskDate, (pickedDate) {
                                setState(() {
                                  taskDate = pickedDate;
                                });
                              }),
                              const SizedBox(height: 20),

                              _buildTimePicker(context, startTime, (pickedTime) {
                                setState(() {
                                  startTime = pickedTime;
                                });
                              }, label: '시작 시간'),
                              const SizedBox(height: 20),

                              _buildTimePicker(context, endTime, (pickedTime) {
                                setState(() {
                                  endTime = pickedTime;
                                });
                              }, label: '종료 시간'),
                              const SizedBox(height: 20),

                              _buildImportanceSelector(setState, importanceLevel, (level) {
                                importanceLevel = level;
                              }),
                              const SizedBox(height: 20),

                              _buildDueDatePicker(context, dueDate, (pickedDate) {
                                setState(() {
                                  dueDate = pickedDate;
                                });
                              }),
                              const SizedBox(height: 20),

                              _buildSwitchRow('알림 설정', isImportant, (value) {
                                setState(() {
                                  isImportant = value;
                                });
                              }),

                              // ✅ 사용자 알림 반복 선택
                              if (isImportant) ...[
                                const SizedBox(height: 16),
                                const Text('알림 반복 시간', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  children: [5, 10, 15, 30, 60].map((minute) {
                                    final isSelected = selectedReminders.contains(minute);
                                    return ChoiceChip(
                                      label: Text('$minute분 전'),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedReminders.add(minute);
                                          } else {
                                            selectedReminders.remove(minute);
                                          }
                                        });
                                      },
                                      selectedColor: Colors.purple.shade200,
                                    );
                                  }).toList(),
                                ),
                              ],

                              _buildSwitchRow('반복 일정', isUrgent, (value) {
                                setState(() {
                                  isUrgent = value;
                                });
                              }),
                              const SizedBox(height: 20),

                              _buildTextField(memoController, '메모', '메모', null, maxLines: 3),
                              const SizedBox(height: 20),

                              _buildTextField(locationController, '위치', '위치', null),
                              const SizedBox(height: 30),

                              Center(
                                child: SizedBox(
                                  width: 150,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text('닫기'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }


// 3. 시간 문자열을 TimeOfDay로 변환하는 유틸리티 함수 추가
  TimeOfDay _parseTimeString(String timeString) {
    // 기본값 설정
    if (timeString.isEmpty) {
      return TimeOfDay.now();
    }

    // "AM 09:30" 또는 "PM 03:45" 형식 파싱
    bool isAM = timeString.startsWith('AM');

    final parts = timeString.substring(3).split(':');
    if (parts.length != 2) {
      return TimeOfDay.now();
    }

    try {
      int hour = int.parse(parts[0].trim());
      int minute = int.parse(parts[1].trim());

      // PM인 경우 12시간제 -> 24시간제로 변환
      if (!isAM && hour < 12) {
        hour += 12;
      }
      // AM인 경우 12시는 0시로 변환
      if (isAM && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return TimeOfDay.now();
    }
  }



  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void showAddTaskDialog(BuildContext context) {
    DateTime taskDate = selectedDate;
    DateTime? dueDate;
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay.now().replacing(hour: startTime.hour + 1);

    bool isImportant = false;
    bool isUrgent = false;
    int importanceLevel = 1;
    int urgencyLevel = 1;
    List<int> selectedReminders = []; // ✅ 사용자 선택 알림 시간

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 다이얼로그 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black12)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '새 Todolist 추가',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // 폼 영역
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                titleController,
                                '제목',
                                '제목을 입력하세요 (필수)',
                                    (value) {
                                  if (value.isEmpty) {
                                    _showSnackBar(context, '제목을 입력해주세요');
                                  }
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildDatePicker(context, taskDate, (pickedDate) {
                                setState(() {
                                  taskDate = pickedDate;
                                });
                              }),
                              const SizedBox(height: 20),

                              _buildTimePicker(context, startTime, (pickedTime) {
                                setState(() {
                                  startTime = pickedTime;
                                });
                              }, label: '시작 시간'),

                              const SizedBox(height: 20),

                              _buildTimePicker(context, endTime, (pickedTime) {
                                setState(() {
                                  endTime = pickedTime;
                                });
                              }, label: '종료 시간'),

                              const SizedBox(height: 20),

                              _buildImportanceSelector(setState, importanceLevel, (level) {
                                importanceLevel = level;
                              }),
                              const SizedBox(height: 20),

                              _buildDueDatePicker(
                                  context,
                                  selectedDueDate,
                                      (pickedDate) {
                                    setState(() {
                                      selectedDueDate = pickedDate;
                                    });
                                  }),

                              const SizedBox(height: 20),

                              _buildSwitchRow('알림 설정', isImportant, (value) {
                                setState(() {
                                  isImportant = value;
                                });
                              }),

                              // ✅ 알림 설정이 true일 때만 반복 시간 선택 보이기
                              if (isImportant) ...[
                                const SizedBox(height: 16),
                                const Text('알림 반복 시간', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  children: [5, 10, 15, 30, 60].map((minute) {
                                    final isSelected = selectedReminders.contains(minute);
                                    return ChoiceChip(
                                      label: Text('$minute분 전'),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedReminders.add(minute);
                                          } else {
                                            selectedReminders.remove(minute);
                                          }
                                        });
                                      },
                                      selectedColor: Colors.purple.shade200,
                                    );
                                  }).toList(),
                                ),
                              ],

                              _buildSwitchRow('반복 일정', isUrgent, (value) {
                                setState(() {
                                  isUrgent = value;
                                });
                              }),
                              const SizedBox(height: 20),

                              _buildTextField(memoController, '메모', '메모', null, maxLines: 3),
                              const SizedBox(height: 20),

                              _buildTextField(locationController, '위치', '위치', null),
                              const SizedBox(height: 30),

                              Center(
                                child: SizedBox(
                                  width: 150,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (titleController.text.isEmpty) {
                                        _showSnackBar(context, '제목을 입력해주세요');
                                        return;
                                      }

                                      final String formattedStart =
                                          '${startTime.period == DayPeriod.am ? 'AM' : 'PM'} ${startTime.hourOfPeriod.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                                      final String formattedEnd =
                                          '${endTime.period == DayPeriod.am ? 'AM' : 'PM'} ${endTime.hourOfPeriod.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                                      final newTask = Todo_Task(
                                        title: titleController.text,
                                        date: taskDate,
                                        time: formattedStart,
                                        endTime: formattedEnd,
                                        isImportant: isImportant,
                                        isUrgent: isUrgent,
                                        memo: memoController.text,
                                        location: locationController.text,
                                        importance: importanceLevel,
                                        urgency: urgencyLevel,
                                        isCompleted: false,
                                        color: _getFixedColorForTask(titleController.text),
                                        dueDate: selectedDueDate,
                                        reminderMinutesBefore: isImportant ? selectedReminders : [],
                                      );

                                      if (isImportant) {
                                        _scheduleNotificationsForTask(newTask);
                                      }

                                      _taskDataService.addTodoTask(newTask);
                                      Navigator.of(context).pop();
                                      setState(() {
                                        selectedDate = taskDate;
                                        calculateProgress();
                                      });

                                      if (widget.onTaskStatusChanged != null) {
                                        widget.onTaskStatusChanged!();
                                      }
                                      _showSnackBar(context, '일정이 저장되었습니다');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9575CD),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text('저장'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }



  // TextField 생성 메서드
  Widget _buildTextField(TextEditingController controller, String label, String hint, Function(String)? validator, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: UnderlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          maxLines: maxLines,
          onChanged: validator,
        ),
      ],
    );
  }

  // 날짜 선택기 메서드
  Widget _buildDatePicker(BuildContext context, DateTime taskDate, Function(DateTime) onDatePicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('날짜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: taskDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onDatePicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.calendar_today, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
      BuildContext context,
      TimeOfDay selectedTime,
      Function(TimeOfDay) onTimePicked, {
        String label = '시간',
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked != null) {
                onTimePicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedTime.period == DayPeriod.am ? 'AM' : 'PM'} ${selectedTime.hourOfPeriod.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.access_time, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }



  // 중요도 선택기 메서드
  Widget _buildImportanceSelector(StateSetter setState, int importanceLevel, Function(int) onLevelSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('중요도', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('중요도 (필수):'),
              Row(
                children: List.generate(3, (index) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        onLevelSelected(index + 1);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: importanceLevel == index + 1 ? Colors.blue.shade300 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: importanceLevel == index + 1 ? Colors.white : Colors.black87,
                          fontWeight: importanceLevel == index + 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 마감일 선택기 메서드 (DatePicker 기반)
  Widget _buildDueDatePicker(BuildContext context, DateTime? dueDate, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('마감일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onPicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dueDate != null
                        ? '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}'
                        : '날짜를 선택하세요',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  // 스위치 행 생성 메서드
  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.purple.shade300,
            ),
          ],
        ),
      ),
    );
  }

  // SnackBar 표시 메서드
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // DateTime을 String 키로 변환하는 메서드 추가
  String _dateToKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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