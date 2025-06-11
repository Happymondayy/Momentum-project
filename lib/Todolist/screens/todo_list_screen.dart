import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../Planner/DailyPlannerPage.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'package:collection/collection.dart';
import 'package:momentum_planner/custom_calendar_picker.dart';
import 'package:momentum_planner/time_picker_helper.dart';

class Todo_Task {
  String id;
  String userId; // 이 필드 추가
  String title;
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
  List<int>? reminderMinutesBefore;

  // 반복 관련 필드
  bool isRepeating;
  String? repeatOption;
  List<int>? repeatDays;
  int? repeatCustomDays;

  Todo_Task({
    this.id = '',
    required this.userId, // 필수 필드로 변경
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
    this.isRepeating = false,
    this.repeatOption,
    this.repeatDays,
    this.repeatCustomDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId, // 추가
      'title': title,
      'description': description,
      'time': time,
      'endTime': endTime,
      'date': date.toIso8601String(),
      'isImportant': isImportant,
      'isUrgent': isUrgent,
      'memo': memo,
      'location': location,
      'importance': importance,
      'urgency': urgency,
      'isCompleted': isCompleted,
      'color': color != null ? color!.value : null,
      'dueDate': dueDate?.toIso8601String(),
      'notificationId': notificationId,
      'reminderMinutesBefore': reminderMinutesBefore,
      'isRepeating': isRepeating,
      'repeatOption': repeatOption,
      'repeatDays': repeatDays,
      'repeatCustomDays': repeatCustomDays,
    };
  }

  factory Todo_Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Color? taskColor;
    if (data['color'] != null) {
      taskColor = Color(data['color']);
    }

    // repeatDays 안전하게 파싱하는 헬퍼 함수
    List<int>? _parseRepeatDaysFromFirestore(dynamic repeatDaysData) {
      if (repeatDaysData == null) return null;

      try {
        if (repeatDaysData is List) {
          return repeatDaysData.map((e) {
            if (e is int) return e;
            if (e is String) {
              final parsed = int.tryParse(e);
              return parsed ?? 0;
            }
            return 0;
          }).where((e) => e >= 0 && e <= 6).toList();
        } else if (repeatDaysData is String) {
          String cleanString = repeatDaysData.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');
          if (cleanString.isEmpty) return null;

          return cleanString
              .split(',')
              .map((s) {
            final parsed = int.tryParse(s.trim());
            return parsed ?? 0;
          })
              .where((e) => e >= 0 && e <= 6)
              .toList();
        }
      } catch (e) {
        print('fromFirestore repeatDays 파싱 오류: $e, 데이터: $repeatDaysData');
      }

      return null;
    }



    List<int>? _parseReminderMinutes(dynamic reminderData) {
      if (reminderData == null) return null;

      try {
        if (reminderData is List) {
          return reminderData.map((e) {
            if (e is int) return e;
            if (e is String) {
              final parsed = int.tryParse(e);
              return parsed ?? 0;
            }
            return 0;
          }).toList();
        }
      } catch (e) {
        print('reminderMinutesBefore 파싱 오류: $e');
      }

      return null;
    }

    return Todo_Task(
      id: doc.id,
      userId: data['userId'] ?? '',
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
      // 수정된 부분: 안전하게 파싱
      reminderMinutesBefore: _parseReminderMinutes(data['reminderMinutesBefore']),
      isRepeating: data['isRepeating'] ?? false,
      repeatOption: data['repeatOption'],
      // 수정된 부분: 안전하게 파싱
      repeatDays: _parseRepeatDaysFromFirestore(data['repeatDays']),
      repeatCustomDays: data['repeatCustomDays'],
    );
  }
  // Todo_Task 객체를 Firestore 문서로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId, // 추가
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
      'color': color?.value,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'notificationId': notificationId,
      'reminderMinutesBefore': reminderMinutesBefore,
      'isRepeating': isRepeating,
      'repeatOption': repeatOption,
      'repeatDays': repeatDays,
      'repeatCustomDays': repeatCustomDays,
    };
  }

  // 복사 메서드도 수정
  Todo_Task copyWith({
    String? id,
    String? userId, // 추가
    String? title,
    String? description,
    String? time,
    String? endTime,
    DateTime? date,
    bool? isImportant,
    bool? isUrgent,
    String? memo,
    String? location,
    int? importance,
    int? urgency,
    Color? color,
    DateTime? dueDate,
    bool? isCompleted,
    int? notificationId,
    List<int>? reminderMinutesBefore,
    bool? isRepeating,
    String? repeatOption,
    List<int>? repeatDays,
    int? repeatCustomDays,
  }) {
    return Todo_Task(
      id: id ?? this.id,
      userId: userId ?? this.userId, // 추가
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      isImportant: isImportant ?? this.isImportant,
      isUrgent: isUrgent ?? this.isUrgent,
      memo: memo ?? this.memo,
      location: location ?? this.location,
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      color: color ?? this.color,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationId: notificationId ?? this.notificationId,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatOption: repeatOption ?? this.repeatOption,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatCustomDays: repeatCustomDays ?? this.repeatCustomDays,
    );
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
    int completedTasks = tasks
        .where((task) => task.isCompleted)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FA),
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
          const Text('Your Progress Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          // 진행률 바와 완료 표시
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              height: 10,
                              width: constraints.maxWidth * (progressPercentage / 100),
                              decoration: BoxDecoration(
                                color: progressPercentage == 100
                                    ? const Color(0xFFD1B3F3) // 100% 완료시: 진한 파스텔 보라색
                                    : const Color(0xFFECDBF9), // 진행중: 연한 파스텔 보라색
                                borderRadius: BorderRadius.circular(5),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${progressPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedTasks/$totalTasks Tasks Complete',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (progressPercentage == 100)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🎉 완료!',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
Widget _buildProgressBar(BuildContext context, double progressPercentage,
    int completedTasks, int totalTasks) {
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
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(5)),
                ),
                Container(
                  height: 10,
                  width: MediaQuery
                      .of(context)
                      .size
                      .width * (progressPercentage / 100) * 0.7,
                  decoration: BoxDecoration(
                    color: progressPercentage == 100
                        ? const Color(0xFFD1B3F3) // ✅ 파스텔 연보라색
                        : const Color(0xFFECDBF9), // 기본 진행색
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Text(
            '${progressPercentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '$completedTasks/$totalTasks Task Complete',
        style: const TextStyle(fontSize: 13, color: Colors.black),
      ),
    ],
  );
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
  final double? progressPercentage;

  const TodoListScreen({
    Key? key,
    this.initialDate,
    this.isEmbedded = false,
    this.onStateCreated,
    this.onTaskStatusChanged,
    this.taskDataService,
    this.progressPercentage,
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

    // 데이터 로드 및 진행률 계산
    if (_taskDataService.currentUserId != null) {
      _taskDataService.loadTasksFromFirestore(_taskDataService.currentUserId!).then((_) {
        calculateProgress();
      });
    } else {
      calculateProgress();
    }
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

  // 수정된 진행률 계산 함수
  void calculateProgress() {
    if (!mounted) return;

    setState(() {
      // 외부에서 진행률을 받는 경우 (플래너에서 임베딩된 경우)
      if (widget.progressPercentage != null) {
        progressPercentage = widget.progressPercentage!;
      } else {
        // 독립적인 투두리스트 화면인 경우 투두 진행률만 계산
        final todoTasks = getTasksForSelectedDate();
        if (todoTasks.isEmpty) {
          progressPercentage = 0.0;
        } else {
          final completedTasks = todoTasks.where((task) => task.isCompleted).length;
          progressPercentage = (completedTasks / todoTasks.length) * 100;
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant TodoListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 외부 진행률이 변경된 경우 업데이트
    if (widget.progressPercentage != oldWidget.progressPercentage) {
      calculateProgress();
    }
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
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
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
        body: Column(
          children: [
            // 고정된 상단 부분
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                ],
              ),
            ),
            // 스크롤 가능한 태스크 리스트 부분
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: tasksForSelectedDate.isEmpty
                    ? _buildEmptyState('오늘 할 일이 없습니다')
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // FloatingActionButton 공간 확보
                  itemCount: tasksForSelectedDate.length,
                  itemBuilder: (context, index) {
                    return _buildTaskItem(tasksForSelectedDate[index]);
                  },
                ),
              ),
            ),
          ],
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

    try {
      // "AM 09" 또는 "PM 03" 형식 처리 (분이 없는 경우)
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        // ":"이 있는 경우와 없는 경우 모두 처리
        int hour = 0;
        int minute = 0;

        if (timePart.contains(':')) {
          final parts = timePart.split(':');
          hour = int.parse(parts[0].trim());
          minute = int.parse(parts[1].trim());
        } else {
          // "AM 09" 형식 (분이 없는 경우)
          hour = int.parse(timePart);
          minute = 0;
        }

        // 12시간제를 24시간제로 변환
        if (!isAM && hour < 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        return DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          hour,
          minute,
        );
      }

      // "HH:mm" 형식 처리 (24시간)
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final hour = int.parse(parts[0].trim());
          final minute = int.parse(parts[1].trim());
          return DateTime(
            taskDate.year,
            taskDate.month,
            taskDate.day,
            hour,
            minute,
          );
        }
      }

      // 숫자만 있는 경우 (예: "14")
      final hourOnly = int.tryParse(timeString.trim());
      if (hourOnly != null) {
        return DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          hourOnly,
          0,
        );
      }

      return taskDate;
    } catch (e) {
      print('시간 파싱 오류: $e (입력: $timeString)');
      return taskDate;
    }
  }

  Widget _buildTaskItem(Todo_Task task) {
    return GestureDetector(
      onTap: () {
        // 태스크 클릭 시 수정 폼 열기
        showTaskDetailDialog(context, task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // 상단 정렬로 변경
                children: [
                  // 체크박스
                  Transform.scale(
                    scale: 1.0,
                    child: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) async {
                        setState(() {
                          if (!task.isCompleted && value == true && task.notificationId != null) {
                            _notificationService.cancelNotification(task.notificationId!);
                            _notificationService.cancelNotification(task.notificationId! + 1000);
                          }
                          task.isCompleted = value ?? false;
                          calculateProgress();
                          if (widget.onTaskStatusChanged != null) {
                            widget.onTaskStatusChanged!();
                          }
                        });

                        // ✅ Firestore에 변경사항 저장 추가
                        try {
                          await _taskDataService.updateTaskInFirestore(task);
                          print('태스크 완료 상태가 Firestore에 저장됨: ${task.title} - ${task.isCompleted}');
                        } catch (e) {
                          print('Firestore 업데이트 오류: $e');
                          // 오류 발생 시 상태 되돌리기
                          setState(() {
                            task.isCompleted = !task.isCompleted;
                            calculateProgress();
                          });
                          _showSnackBar(context, '저장 중 오류가 발생했습니다');
                        }

                        if (value == true) {
                          await _notificationService.showTaskCompletedNotification(task.title);
                        }
                      },
                      shape: CircleBorder(),
                      activeColor: Color(0xFFD1B3F3),
                      checkColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 제목과 날짜 열 - Expanded로 감싸서 남은 공간 모두 사용
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목과 반복 아이콘 - 더 유연한 레이아웃
                        Row(
                          children: [
                            // 제목 - Flexible로 감싸서 긴 제목 처리
                            Flexible(
                              flex: 3,
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: task.isCompleted ? Colors.grey : Colors.black,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                                overflow: TextOverflow.ellipsis, // 긴 제목 처리
                                maxLines: 2, // 최대 2줄까지 표시
                              ),
                            ),
                            // 반복 아이콘 표시 - 공간이 있을 때만 표시
                            if (task.isRepeating) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 1,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat, size: 12, color: Colors.blue.shade700),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          _getRepeatText(task.repeatOption),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 날짜와 시간 - 긴 텍스트 처리
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMM d').format(task.date),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            // 시간이 있을 때만 표시
                            if (task.time != null && task.time!.isNotEmpty) ...[
                              Text(
                                ', ${task.time}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              if (task.endTime != null && task.endTime!.isNotEmpty)
                                Text(
                                  ' - ${task.endTime}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 상태 표시기 - 완료 상태일 때만 표시
                  if (task.isCompleted)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              // 중요도와 긴급도 표시 - Wrap으로 변경하여 화면 넘침 방지
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 48), // 체크박스 위치에 맞춰 들여쓰기
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 중요도 표시
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getImportanceColor(task.importance),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '중요도 ${task.importance}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 긴급도 표시
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getUrgencyColor(task.urgency),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '긴급도 ${task.urgency}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 마감일이 있는 경우
              if (task.dueDate != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14,
                          color: task.isCompleted ? Colors.grey : Colors.deepOrange),
                      const SizedBox(width: 4),
                      Expanded( // 긴 날짜 텍스트 처리
                        child: Text(
                          '마감일: ${DateFormat('yyyy-MM-dd').format(task.dueDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: task.isCompleted ? Colors.grey : Colors.deepOrange,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 메모가 있는 경우 보라색 점 표시
              if (task.memo != null && task.memo!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 6, right: 8, left: 48), // 들여쓰기 조정
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFF9575CD),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.memo!,
                        style: TextStyle(
                          fontSize: 14,
                          color: task.isCompleted ? Colors.grey : Colors.grey.shade700,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        maxLines: 3, // 메모 최대 3줄로 제한
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // 위치가 있는 경우
              if (task.location != null && task.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded( // 긴 위치명 처리
                        child: Text(
                          task.location!,
                          style: TextStyle(
                            color: task.isCompleted ? Colors.grey : Colors.grey.shade600,
                            fontSize: 14,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 반복 정보 상세 표시
              if (task.isRepeating) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Expanded( // 긴 반복 설명 처리
                        child: Text(
                          _getDetailedRepeatText(task.repeatOption, task.repeatDays, task.repeatCustomDays),
                          style: TextStyle(
                            fontSize: 14,
                            color: task.isCompleted ? Colors.grey : Colors.blue.shade600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  // 1. TodoListScreenState 클래스에 추가할 반복 일정 생성 함수
  Future<void> _createRepeatingTasks(Todo_Task originalTask) async {
    if (!originalTask.isRepeating || originalTask.repeatOption == null) {
      return;
    }

    List<DateTime> futureDates = _generateRepeatDates(originalTask);

    for (DateTime futureDate in futureDates) {
      // 원본 태스크를 복사하여 새로운 날짜로 생성
      final repeatedTask = originalTask.copyWith(
        id: '', // 새로운 ID 생성을 위해 빈 문자열
        date: futureDate,
        isCompleted: false, // 반복 태스크는 항상 미완료 상태로 시작
        notificationId: null, // 새로운 알림 ID 생성을 위해 null
      );

      // 알림이 설정되어 있다면 새로운 태스크에도 알림 설정
      if (repeatedTask.isImportant) {
        _scheduleNotificationsForTask(repeatedTask);
      }

      // Firestore와 로컬에 추가
      await _taskDataService.addTodoTask(repeatedTask);
    }
  }

// 2. 반복 날짜들을 생성하는 함수
  List<DateTime> _generateRepeatDates(Todo_Task task) {
    List<DateTime> dates = [];
    DateTime startDate = task.date.add(Duration(days: 1)); // 다음날부터 시작
    DateTime endDate = DateTime.now().add(Duration(days: 365)); // 1년 후까지

    switch (task.repeatOption) {
      case '매일':
        DateTime current = startDate;
        while (current.isBefore(endDate)) {
          dates.add(current);
          current = current.add(Duration(days: 1));
        }
        break;

      case '매주':
        DateTime current = startDate;
        while (current.isBefore(endDate)) {
          dates.add(current);
          current = current.add(Duration(days: 7));
        }
        break;

      case '매달':
        DateTime current = startDate;
        while (current.isBefore(endDate)) {
          dates.add(current);
          // 다음 달의 같은 날
          int nextMonth = current.month + 1;
          int nextYear = current.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          current = DateTime(nextYear, nextMonth, current.day);
        }
        break;

      case '매년':
        DateTime current = startDate;
        while (current.isBefore(endDate)) {
          dates.add(current);
          current = DateTime(current.year + 1, current.month, current.day);
        }
        break;

      case '매요일':
        if (task.repeatDays != null && task.repeatDays!.isNotEmpty) {
          DateTime current = startDate;
          while (current.isBefore(endDate)) {
            // 월요일=0, 화요일=1, ..., 일요일=6
            int currentWeekday = current.weekday - 1; // DateTime.weekday는 1-7이므로 0-6으로 변환

            if (task.repeatDays!.contains(currentWeekday)) {
              dates.add(current);
            }
            current = current.add(Duration(days: 1));
          }
        }
        break;

      case '기타':
        if (task.repeatCustomDays != null && task.repeatCustomDays! > 0) {
          DateTime current = startDate;
          while (current.isBefore(endDate)) {
            dates.add(current);
            current = current.add(Duration(days: task.repeatCustomDays!));
          }
        }
        break;
    }

    return dates;
  }

// 반복 텍스트 헬퍼 함수들
  String _getRepeatText(String? repeatOption) {
    switch (repeatOption) {
      case '매일': return '매일';
      case '매주': return '매주';
      case '매달': return '매달';
      case '매년': return '매년';
      case '매요일': return '요일';
      case '기타': return '사용자';
      default: return '';
    }
  }

  String _getDetailedRepeatText(String? repeatOption, List<int>? repeatDays, int? repeatCustomDays) {
    switch (repeatOption) {
      case '매일':
        return '매일 반복';
      case '매주':
        return '매주 반복';
      case '매달':
        return '매달 반복';
      case '매년':
        return '매년 반복';
      case '매요일':
        if (repeatDays != null && repeatDays.isNotEmpty) {
          final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
          final selectedDays = repeatDays.map((day) => dayNames[day]).join(', ');
          return '$selectedDays요일 반복';
        }
        return '매요일 반복';
      case '기타':
        if (repeatCustomDays != null) {
          return '$repeatCustomDays일마다 반복';
        }
        return '사용자 정의 반복';
      default:
        return '반복 없음';
    }
  }

  // TodoListScreenState 클래스 내부에 추가할 누락된 함수들

// 중요도 라벨 반환 함수
  String _getImportanceLabel(int importance) {
    switch (importance) {
      case 1:
        return '매우 낮음';
      case 2:
        return '낮음';
      case 3:
        return '보통';
      case 4:
        return '높음';
      case 5:
        return '매우 높음';
      default:
        return '보통';
    }
  }

// 긴급도 라벨 반환 함수
  String _getUrgencyLabel(int urgency) {
    switch (urgency) {
      case 1:
        return '매우 낮음';
      case 2:
        return '낮음';
      case 3:
        return '보통';
      case 4:
        return '높음';
      case 5:
        return '매우 높음';
      default:
        return '보통';
    }
  }

// 중요도 선택기 위젯
  Widget _buildImportanceSelector(StateSetter setState, int importance, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '중요도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: importance.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) {
                        setState(() {
                          onChanged(value.round());
                        });
                      },
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = importance == level;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        onChanged(level);
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getImportanceColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getImportanceColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getImportanceColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '현재: ${_getImportanceLabel(importance)}',
                style: TextStyle(
                  color: _getImportanceColor(importance),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 긴급도 선택기 위젯
  Widget _buildUrgencySelector(StateSetter setState, int urgency, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '긴급도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: urgency.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) {
                        setState(() {
                          onChanged(value.round());
                        });
                      },
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = urgency == level;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        onChanged(level);
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getUrgencyColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getUrgencyColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getUrgencyColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '현재: ${_getUrgencyLabel(urgency)}',
                style: TextStyle(
                  color: _getUrgencyColor(urgency),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void showTaskDetailDialog(BuildContext context, Todo_Task task) {
    final titleController = TextEditingController(text: task.title);
    final memoController = TextEditingController(text: task.memo ?? '');
    final locationController = TextEditingController(text: task.location ?? '');
    final repeatCustomDaysController = TextEditingController(
        text: task.repeatCustomDays?.toString() ?? ''
    );

    TimeOfDay? startTime = task.time != null ? _parseTimeString(task.time!) : null;
    TimeOfDay? endTime = task.endTime != null ? _parseTimeString(task.endTime!) : null;

    DateTime taskDate = task.date;
    DateTime? dueDate = task.dueDate;
    bool isImportant = task.isImportant;
    bool isUrgent = task.isUrgent;
    bool isRepeating = task.isRepeating;
    String? repeatOption = task.repeatOption;
    List<int> repeatDays = List<int>.from(task.repeatDays ?? []);
    int? repeatCustomDays = task.repeatCustomDays;

    int importanceLevel = task.importance;
    int urgencyLevel = task.urgency;
    List<int> selectedReminders = List.from(task.reminderMinutesBefore ?? []);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 다이얼로그 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF5F6368)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              '일정 수정',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF202124),
                                letterSpacing: 0.15,
                              ),
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
                          padding: const EdgeInsets.all(20.0),
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
                                prefixIcon: Icon(Icons.title, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 20),

                              _buildDatePicker(context, taskDate, (pickedDate) {
                                setState(() {
                                  taskDate = pickedDate;
                                });
                              }),
                              const SizedBox(height: 20),

                              // 시간 설정 (선택사항)
                              _buildOptionalTimeSelector(context, startTime, endTime, (start, end) {
                                setState(() {
                                  startTime = start;
                                  endTime = end;
                                });
                              }),
                              const SizedBox(height: 20),

                              // 중요도
                              _buildImportanceSelector(setState, importanceLevel, (level) {
                                importanceLevel = level;
                              }),
                              const SizedBox(height: 20),

                              // 긴급도 (중요도 아래)
                              _buildUrgencySelector(setState, urgencyLevel, (level) {
                                urgencyLevel = level;
                              }),
                              const SizedBox(height: 20),

                              // 마감일 (긴급도 아래)
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

                              // 알림 설정이 true일 때만 반복 시간 선택 보이기
                              if (isImportant) ...[
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Text('알림 반복 시간',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF5F6368),
                                      )
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Wrap(
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
                                        selectedColor: Color(0xFFD2C5E8),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // 반복 설정 추가
                              _buildRepeatSelector(setState, isRepeating, repeatOption, repeatDays, repeatCustomDays, repeatCustomDaysController, (repeating, option, days, customDays) {
                                isRepeating = repeating;
                                repeatOption = option;
                                repeatDays = days;
                                repeatCustomDays = customDays;
                              }),

                              const SizedBox(height: 20),

                              _buildTextField(
                                memoController,
                                '메모',
                                '메모를 입력하세요.',
                                null,
                                maxLines: 3,
                                prefixIcon: Icon(Icons.note, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 20),

                              _buildTextField(
                                locationController,
                                '위치',
                                '위치를 입력하세요.',
                                null,
                                prefixIcon: Icon(Icons.location_on, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 30),

                              // 수정 및 삭제 버튼
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 삭제 버튼
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          // 삭제 확인 다이얼로그
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('일정 삭제'),
                                              content: Text('정말로 이 일정을 삭제하시겠습니까?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: Text('취소'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    // 알림 취소
                                                    if (task.notificationId != null) {
                                                      _notificationService.cancelNotification(task.notificationId!);
                                                      _notificationService.cancelNotification(task.notificationId! + 1000);
                                                    }

                                                    // Firestore에서 삭제
                                                    await _taskDataService.removeTaskFromFirestore(task);

                                                    // 로컬 데이터에서 삭제
                                                    await _taskDataService.removeTask(task);

                                                    Navigator.pop(context); // 확인 다이얼로그 닫기
                                                    Navigator.pop(context); // 수정 다이얼로그 닫기

                                                    this.setState(() {
                                                      calculateProgress();
                                                    });

                                                    if (widget.onTaskStatusChanged != null) {
                                                      widget.onTaskStatusChanged!();
                                                    }

                                                    _showSnackBar(context, '일정이 삭제되었습니다');
                                                  },
                                                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade400,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text('삭제'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // 수정 버튼
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (titleController.text.isEmpty) {
                                            _showSnackBar(context, '제목을 입력해주세요');
                                            return;
                                          }

                                          String? formattedStart;
                                          String? formattedEnd;

                                          if (startTime != null) {
                                            formattedStart = '${startTime!.period == DayPeriod.am ? 'AM' : 'PM'} ${startTime!.hourOfPeriod.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                                          }

                                          if (endTime != null) {
                                            formattedEnd = '${endTime!.period == DayPeriod.am ? 'AM' : 'PM'} ${endTime!.hourOfPeriod.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
                                          }

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

                                          // 태스크 업데이트
                                          task.title = titleController.text;
                                          task.date = taskDate; // 날짜 변경도 반영
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
                                          task.isRepeating = isRepeating;
                                          task.repeatOption = repeatOption;
                                          task.repeatDays = repeatDays.isNotEmpty ? repeatDays : null;
                                          task.repeatCustomDays = repeatCustomDays;

                                          if (isImportant) {
                                            _scheduleNotificationsForTask(task);
                                          }

                                          // Firestore 업데이트 (새로운 함수 사용)
                                          await _taskDataService.updateTaskInFirestore(task);

                                          // 반복 설정이 새로 추가되었다면 반복 태스크들 생성
                                          if (isRepeating && !task.isRepeating) {
                                            await _createRepeatingTasks(task);
                                            _showSnackBar(context, '반복 일정이 추가로 생성되었습니다');
                                          } else {
                                            _showSnackBar(context, '일정이 수정되었습니다');
                                          }


                                          Navigator.of(context).pop();
                                          this.setState(() {
                                            calculateProgress();
                                          });

                                          if (widget.onTaskStatusChanged != null) {
                                            widget.onTaskStatusChanged!();
                                          }

                                          _showSnackBar(context, '일정이 수정되었습니다');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF9575CD),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text('수정'),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      repeatCustomDaysController.dispose();
      this.setState(() {
        calculateProgress();
      });
    });
  }


  TimeOfDay _parseTimeString(String timeString) {
    if (timeString.isEmpty) {
      return TimeOfDay.now();
    }

    try {
      // "AM 09" 또는 "PM 03" 형식 처리
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        int hour = 0;
        int minute = 0;

        if (timePart.contains(':')) {
          final parts = timePart.split(':');
          // Leading zero 안전 파싱
          hour = int.tryParse(parts[0].trim()) ?? 0;
          minute = int.tryParse(parts[1].trim()) ?? 0;
        } else {
          // "AM 09" 형식 - Leading zero 안전 파싱
          hour = int.tryParse(timePart.trim()) ?? 0;
          minute = 0;
        }

        // 12시간제를 24시간제로 변환
        if (!isAM && hour < 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: minute);
      }

      // "HH:mm" 형식 처리 (24시간)
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0].trim()) ?? 0;
          final minute = int.tryParse(parts[1].trim()) ?? 0;
          return TimeOfDay(hour: hour, minute: minute);
        }
      }

      // 숫자만 있는 경우
      final hourOnly = int.tryParse(timeString.trim());
      if (hourOnly != null) {
        return TimeOfDay(hour: hourOnly, minute: 0);
      }

      return TimeOfDay.now();
    } catch (e) {
      print('시간 파싱 오류 해결됨: $e (입력: $timeString)');
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

  // 반복 설정 UI 빌더
  Widget _buildRepeatSelector(
      StateSetter setState,
      bool isRepeating,
      String? repeatOption,
      List<int> repeatDays,
      int? repeatCustomDays,
      TextEditingController repeatCustomDaysController,
      Function(bool, String?, List<int>, int?) onChanged
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwitchRow('반복 설정', isRepeating, (value) {
          setState(() {
            onChanged(value, value ? '매일' : null, [], null);
          });
        }),
        if (isRepeating) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: repeatOption,
                hint: Text('반복 주기 선택'),
                items: [
                  DropdownMenuItem(value: '매일', child: Text('매일')),
                  DropdownMenuItem(value: '매주', child: Text('매주')),
                  DropdownMenuItem(value: '매달', child: Text('매달')),
                  DropdownMenuItem(value: '매년', child: Text('매년')),
                  DropdownMenuItem(value: '매요일', child: Text('매요일')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    if (value == '매요일' && repeatDays.isEmpty) {
                      final now = DateTime.now();
                      int weekday = now.weekday - 1; // 0-6으로 변환 (월-일)
                      onChanged(isRepeating, value, [weekday], null);
                    } else {
                      onChanged(isRepeating, value, repeatDays, repeatCustomDays);
                    }
                  });
                },
              ),
            ),
          ),
          if (repeatOption == '매요일') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(['월', '화', '수', '목', '금', '토', '일'][i]),
                    selected: repeatDays.contains(i),
                    onSelected: (selected) {
                      setState(() {
                        List<int> newDays = List<int>.from(repeatDays);
                        if (selected) {
                          newDays.add(i);
                        } else {
                          if (newDays.length > 1) {
                            newDays.remove(i);
                          } else {
                            _showSnackBar(context, '적어도 하나의 요일을 선택해야 합니다');
                            return;
                          }
                        }
                        onChanged(isRepeating, repeatOption, newDays, repeatCustomDays);
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.deepPurple[100],
                    checkmarkColor: Colors.deepPurple,
                  ),
              ],
            ),
          ] else if (repeatOption == '기타') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: repeatCustomDaysController,
                      decoration: InputDecoration(
                        hintText: '날짜 간격',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final customDays = int.tryParse(value);
                        onChanged(isRepeating, repeatOption, repeatDays, customDays);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('일마다', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ],
      ],
    );
  }

  // 선택적 시간 설정 UI 빌더 (CustomTimePicker 사용)
  Widget _buildOptionalTimeSelector(
      BuildContext context,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      Function(TimeOfDay?, TimeOfDay?) onTimeChanged
      ) {
    bool hasTime = startTime != null || endTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwitchRow('시간 설정', hasTime, (value) {
          if (value) {
            final now = TimeOfDay.now();
            final nextHour = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
            onTimeChanged(now, nextHour);
          } else {
            onTimeChanged(null, null);
          }
        }),
        if (hasTime) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOptionalTimePicker(
                    context,
                    startTime ?? TimeOfDay.now(),
                    '시작 시간',
                        (time) => onTimeChanged(time, endTime)
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOptionalTimePicker(
                    context,
                    endTime ?? TimeOfDay.now(),
                    '종료 시간 (선택)',
                        (time) => onTimeChanged(startTime, time)
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

// 선택적 시간 선택기 (CustomTimePicker 사용)
  Widget _buildOptionalTimePicker(
      BuildContext context,
      TimeOfDay selectedTime,
      String label,
      Function(TimeOfDay) onTimePicked,
      ) {
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
              final TimeOfDay? picked = await showCustomTimePicker(
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

  // ✅ 기존 함수를 이렇게 간단하게 교체
  void showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AddTaskDialog(
        initialDate: selectedDate,
        taskDataService: _taskDataService,
        notificationService: _notificationService,
        onTaskAdded: (Todo_Task newTask) async {
          // 알림 설정
          if (newTask.isImportant) {
            _scheduleNotificationsForTask(newTask);
          }

          // 태스크 추가
          await _taskDataService.addTodoTask(newTask);

          // 반복 태스크 생성
          if (newTask.isRepeating) {
            await _createRepeatingTasks(newTask);
          }

          // UI 업데이트
          if (mounted) {
            setState(() {
              selectedDate = newTask.date;
              calculateProgress();
            });

            if (widget.onTaskStatusChanged != null) {
              widget.onTaskStatusChanged!();
            }
          }
        },
      ),
    );
  }

// 텍스트필드 위젯 개선
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      String hint,
      Function(String)? validator, {
        int maxLines = 1,
        Widget? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
            prefixIcon: prefixIcon,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFDADCE0), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF9575CD), width: 1.5),
            ),
          ),
          validator: validator != null ? (value) {
            validator(value ?? '');
            return null;
          } : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context, DateTime taskDate, Function(DateTime) onDatePicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('날짜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DateSelectorBox(
          label: '',  // 이미 위에 '날짜' 라벨이 있으므로 빈 문자열
          date: taskDate,
          primaryColor: const Color(0xFF5E4DAE), // 원하는 색상으로 변경 가능
          onTap: () async {
            final DateTime? picked = await CalendarPickerUtils.showCalendarPicker(
              context: context,
              initialDate: taskDate,
              minDate: DateTime(2020),
              maxDate: DateTime(2030),
              title: '날짜 선택',
              primaryColor: const Color(0xFF5E4DAE), // 원하는 색상으로 변경 가능
            );
            if (picked != null) {
              onDatePicked(picked);
            }
          },
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

  Widget buildImportanceSelector({
    required int importance,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '중요도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: importance.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) => onChanged(value.round()),
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = importance == level;
                  return GestureDetector(
                    onTap: () => onChanged(level),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getImportanceColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getImportanceColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getImportanceColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '현재: ${_getImportanceLabel(importance)}',
                style: TextStyle(
                  color: _getImportanceColor(importance),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 4. buildUrgencySelector 함수 완전 교체
  Widget buildUrgencySelector({
    required int urgency,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '긴급도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: urgency.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) => onChanged(value.round()),
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = urgency == level;
                  return GestureDetector(
                    onTap: () => onChanged(level),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getUrgencyColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getUrgencyColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getUrgencyColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '현재: ${_getUrgencyLabel(urgency)}',
                style: TextStyle(
                  color: _getUrgencyColor(urgency),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
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
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await CalendarPickerUtils.showCalendarPicker(
                context: context,
                initialDate: dueDate ?? DateTime.now(),
                minDate: DateTime(2020),
                maxDate: DateTime(2030),
                title: '마감일 선택',
                primaryColor: const Color(0xFF5E4DAE), // 원하는 색상으로 변경 가능
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
                        ? '${dueDate.year}년 ${dueDate.month}월 ${dueDate.day}일'
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

// ✅ 완전히 새로운 접근법: 별도의 StatefulWidget으로 다이얼로그 생성
class AddTaskDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(Todo_Task) onTaskAdded;
  final dynamic taskDataService;
  final NotificationService notificationService;

  const AddTaskDialog({
    Key? key,
    required this.initialDate,
    required this.onTaskAdded,
    required this.taskDataService,
    required this.notificationService,
  }) : super(key: key);

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late TextEditingController titleController;
  late TextEditingController memoController;
  late TextEditingController locationController;
  late TextEditingController repeatCustomDaysController;

  late DateTime taskDate;
  DateTime? selectedDueDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  bool isImportant = false;
  bool isUrgent = false;
  bool isRepeating = false;
  String? repeatOption;
  List<int> repeatDays = [];
  int? repeatCustomDays;

  int importanceLevel = 1;
  int urgencyLevel = 1;
  List<int> selectedReminders = [];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    memoController = TextEditingController();
    locationController = TextEditingController();
    repeatCustomDaysController = TextEditingController();
    taskDate = widget.initialDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    memoController.dispose();
    locationController.dispose();
    repeatCustomDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 다이얼로그 헤더
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF5F6368)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '새 Todolist 추가',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
                        letterSpacing: 0.15,
                      ),
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
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        titleController,
                        '제목',
                        '제목을 입력하세요 (필수)',
                        prefixIcon: Icon(Icons.title, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 20),

                      _buildDatePicker(),
                      const SizedBox(height: 20),

                      _buildTimeSelector(),
                      const SizedBox(height: 20),

                      _buildImportanceSelector(),
                      const SizedBox(height: 20),

                      _buildUrgencySelector(),
                      const SizedBox(height: 20),

                      _buildDueDatePicker(),
                      const SizedBox(height: 20),

                      _buildNotificationSettings(),
                      const SizedBox(height: 20),

                      _buildRepeatSettings(),
                      const SizedBox(height: 20),

                      _buildTextField(
                        memoController,
                        '메모',
                        '메모',
                        maxLines: 3,
                        prefixIcon: Icon(Icons.note, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        locationController,
                        '위치',
                        '위치',
                        prefixIcon: Icon(Icons.location_on, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 30),

                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      String hint, {
        int maxLines = 1,
        Widget? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
            prefixIcon: prefixIcon,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFDADCE0), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF9575CD), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('날짜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: taskDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  taskDate = picked;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${taskDate.year}년 ${taskDate.month}월 ${taskDate.day}일',
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

  Widget _buildTimeSelector() {
    bool hasTime = startTime != null || endTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('시간 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Switch(
              value: hasTime,
              onChanged: (value) {
                setState(() {
                  if (value) {
                    final now = TimeOfDay.now();
                    startTime = now;
                    endTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
                  } else {
                    startTime = null;
                    endTime = null;
                  }
                });
              },
              activeColor: Colors.purple.shade300,
            ),
          ],
        ),
        if (hasTime) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  startTime ?? TimeOfDay.now(),
                  '시작 시간',
                      (time) => setState(() => startTime = time),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(
                  endTime ?? TimeOfDay.now(),
                  '종료 시간',
                      (time) => setState(() => endTime = time),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimePicker(TimeOfDay selectedTime, String label, Function(TimeOfDay) onTimePicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${selectedTime.period == DayPeriod.am ? 'AM' : 'PM'} ${selectedTime.hourOfPeriod.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportanceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('중요도', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final level = index + 1;
            final isSelected = importanceLevel == level;
            return GestureDetector(
              onTap: () => setState(() => importanceLevel = level),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _getImportanceColor(level) : Colors.transparent,
                  border: Border.all(color: _getImportanceColor(level), width: 2),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: TextStyle(
                      color: isSelected ? Colors.white : _getImportanceColor(level),
                      fontWeight: FontWeight.bold,
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

  Widget _buildUrgencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('긴급도', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final level = index + 1;
            final isSelected = urgencyLevel == level;
            return GestureDetector(
              onTap: () => setState(() => urgencyLevel = level),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _getUrgencyColor(level) : Colors.transparent,
                  border: Border.all(color: _getUrgencyColor(level), width: 2),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: TextStyle(
                      color: isSelected ? Colors.white : _getUrgencyColor(level),
                      fontWeight: FontWeight.bold,
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

  Widget _buildDueDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('마감일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  selectedDueDate = picked;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                selectedDueDate != null
                    ? '${selectedDueDate!.year}년 ${selectedDueDate!.month}월 ${selectedDueDate!.day}일'
                    : '날짜를 선택하세요',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('알림 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Switch(
              value: isImportant,
              onChanged: (value) => setState(() => isImportant = value),
              activeColor: Colors.purple.shade300,
            ),
          ],
        ),
        if (isImportant) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
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
                selectedColor: Color(0xFFD2C5E8),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRepeatSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('반복 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Switch(
              value: isRepeating,
              onChanged: (value) => setState(() {
                isRepeating = value;
                if (value && repeatOption == null) {
                  repeatOption = '매일';
                }
              }),
              activeColor: Colors.purple.shade300,
            ),
          ],
        ),
        if (isRepeating) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: repeatOption,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ['매일', '매주', '매달', '매년'].map((option) {
              return DropdownMenuItem(value: option, child: Text(option));
            }).toList(),
            onChanged: (value) => setState(() => repeatOption = value),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: SizedBox(
        width: 150,
        child: ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF9575CD),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: const Text('저장'),
        ),
      ),
    );
  }

  void _saveTask() async {
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    String? formattedStart;
    String? formattedEnd;

    if (startTime != null) {
      formattedStart = '${startTime!.period == DayPeriod.am ? 'AM' : 'PM'} ${startTime!.hourOfPeriod.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
    }

    if (endTime != null) {
      formattedEnd = '${endTime!.period == DayPeriod.am ? 'AM' : 'PM'} ${endTime!.hourOfPeriod.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
    }

    final newTask = Todo_Task(
      userId: widget.taskDataService.currentUserId ?? '',
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
      isRepeating: isRepeating,
      repeatOption: repeatOption,
      repeatDays: repeatDays.isNotEmpty ? repeatDays : null,
      repeatCustomDays: repeatCustomDays,
    );

    // 다이얼로그 먼저 닫기
    Navigator.of(context).pop();

    // 태스크 추가
    widget.onTaskAdded(newTask);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('일정이 저장되었습니다')),
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
}

// 중요도 색상 반환 함수 (1-5 레벨)
Color _getImportanceColor(int importance) {
  switch (importance) {
    case 1:
      return Colors.blue.shade300;
    case 2:
      return Colors.green.shade400;
    case 3:
      return Colors.orange.shade400;
    case 4:
      return Colors.red.shade400;
    case 5:
      return Colors.purple.shade500;
    default:
      return Colors.grey.shade400;
  }
}

// 긴급도 색상 반환 함수 (1-5 레벨)
Color _getUrgencyColor(int urgency) {
  switch (urgency) {
    case 1:
      return Colors.teal.shade300;
    case 2:
      return Colors.cyan.shade400;
    case 3:
      return Colors.amber.shade500;
    case 4:
      return Colors.deepOrange.shade400;
    case 5:
      return Colors.red.shade600;
    default:
      return Colors.grey.shade400;
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