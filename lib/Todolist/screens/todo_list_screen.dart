import 'dart:math';
import 'package:flutter/material.dart';

class Task {
  final String title;
  final String? description;
  final String? time;
  final DateTime date;
  final bool isImportant; // 알림 설정
  final bool isUrgent;    // 반복 일정
  final String? memo;
  final String? location;
  final int importance;   // 중요도 (1-3)
  final int urgency;      // 마감일 임박도 (1-3)
  bool isCompleted;       // 일정 완료 여부

  Task({
    required this.title,
    this.description,
    this.time,
    required this.date,
    required this.isImportant,
    required this.isUrgent,
    this.memo,
    this.location,
    required this.importance,
    required this.urgency,
    this.isCompleted = false,
  });
}

class ProgressScreen extends StatelessWidget {
  final List<Task> tasks;
  final double progressPercentage;

  const ProgressScreen({
    Key? key,
    required this.tasks,
    required this.progressPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalTasks = tasks.isEmpty ? 0 : tasks.length;
    int completedTasks = tasks.isEmpty ? 0 : tasks.where((task) => task.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
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
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(5)),
                  ),
                  Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * (progressPercentage / 100) * 0.7,
                    decoration: BoxDecoration(
                        color: progressPercentage == 100
                            ? Colors.green
                            : const Color(0xFFECDBF9),
                        borderRadius: BorderRadius.circular(5)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Text('${progressPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Text('$completedTasks/$totalTasks Task Complete',
            style: const TextStyle(fontSize: 13, color: Colors.black)),
      ],
    );
  }
}

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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
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

class WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WeeklyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateTime weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final currentDate = weekStart.add(Duration(days: index));
              final isSelected = currentDate.year == selectedDate.year &&
                  currentDate.month == selectedDate.month &&
                  currentDate.day == selectedDate.day;

              return GestureDetector(
                onTap: () => onDateSelected(currentDate),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: isSelected
                      ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.withOpacity(0.2),
                  )
                      : null,
                  child: Center(
                    child: Text(
                      '${currentDate.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.purple : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  final DateTime? initialDate; // 초기 선택 날짜 추가

  const TodoListScreen({
    Key? key,
    this.initialDate,
    this.isEmbedded = false,
    this.onStateCreated,
  }) : super(key: key);

  final bool isEmbedded;
  final Function(TodoListScreenState)? onStateCreated;

  @override
  State<TodoListScreen> createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  Map<String, List<Task>> tasksByDate = {};
  DateTime selectedDate = DateTime.now();
  double progressPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }
    if (widget.onStateCreated != null) {
      widget.onStateCreated!(this);
    }
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Task> getTasksForSelectedDate() {
    final dateKey = _dateToKey(selectedDate);
    return tasksByDate[dateKey] ?? [];
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

  @override
  Widget build(BuildContext context) {
    final tasksForSelectedDate = getTasksForSelectedDate();

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
        title: const Text('Todo List'),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonthSelector(
                selectedDate: selectedDate,
                onMonthChanged: (newDate) {
                  setState(() {
                    selectedDate = newDate;
                  });
                },
              ),
              WeeklyCalendar(
                selectedDate: selectedDate,
                onDateSelected: changeSelectedDate,
              ),
              ProgressScreen(
                tasks: tasksForSelectedDate,
                progressPercentage: progressPercentage,
              ),
              const SizedBox(height: 10),
              _buildTodoSectionHeader(
                  isSameDay(selectedDate, DateTime.now())
                      ? 'My Today Tasks'
                      : 'Tasks for ${selectedDate.month}/${selectedDate.day}'
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTodoList(BuildContext context, {required List<Task> tasks}) {
    if (tasks.isEmpty) {
      return _buildEmptyState('오늘 할 일이 없습니다');
    }

    return Column(
      children: tasks.map((task) {
        return _buildTaskItem(task);
      }).toList(),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: getBrightPastelColor(),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (task.time != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.time!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (task.location != null) ...[
                    const SizedBox(height: 4),
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
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) {
                  setState(() {
                    task.isCompleted = value ?? false;
                    calculateProgress();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void showAddTaskDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController memoController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    DateTime taskDate = selectedDate;
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isImportant = false;
    bool isUrgent = false;
    int importanceLevel = 1;
    int urgencyLevel = 1;

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
                        border: Border(
                          bottom: BorderSide(color: Colors.black12),
                        ),
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
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
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('제목',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      )
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: titleController,
                                    decoration: const InputDecoration(
                                      hintText: '제목을 입력하세요 (필수)',
                                      border: UnderlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 날짜 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('날짜',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      )
                                  ),
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
                                              '${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            const Icon(Icons.calendar_today, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 시간 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('시간',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      )
                                  ),
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
                                          setState(() {
                                            selectedTime = picked;
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
                              ),
                              const SizedBox(height: 20),

                              // 중요도 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('중요도',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                                                  importanceLevel = index + 1;
                                                });
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: importanceLevel == index + 1
                                                      ? Colors.blue.shade300
                                                      : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text('${index + 1}',
                                                  style: TextStyle(
                                                    color: importanceLevel == index + 1
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: importanceLevel == index + 1
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
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
                              ),
                              const SizedBox(height: 20),

                              // 마감일 임박도 선택
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('마감일 임박도',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('임박도 (필수):'),
                                        Row(
                                          children: List.generate(3, (index) {
                                            return InkWell(
                                              onTap: () {
                                                setState(() {
                                                  urgencyLevel = index + 1;
                                                });
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: urgencyLevel == index + 1
                                                      ? Colors.red.shade300
                                                      : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text('${index + 1}',
                                                  style: TextStyle(
                                                    color: urgencyLevel == index + 1
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: urgencyLevel == index + 1
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
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
                              ),
                              const SizedBox(height: 20),

                              // 알림 설정
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('알림 설정',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Switch(
                                        value: isImportant,
                                        onChanged: (bool value) {
                                          setState(() {
                                            isImportant = value;
                                          });
                                        },
                                        activeColor: Colors.purple.shade300,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 반복 일정
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('반복 일정',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Switch(
                                        value: isUrgent,
                                        onChanged: (bool value) {
                                          setState(() {
                                            isUrgent = value;
                                          });
                                        },
                                        activeColor: Colors.purple.shade300,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 메모 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('메모',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: memoController,
                                      decoration: const InputDecoration(
                                        hintText: '메모',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                      maxLines: 3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 위치 입력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('위치',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: locationController,
                                      decoration: const InputDecoration(
                                        hintText: '위치',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),

                              // 저장 버튼
                              Center(
                                child: SizedBox(
                                  width: 150,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (titleController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('제목을 입력해주세요')),
                                        );
                                        return;
                                      }

                                      final newTask = Task(
                                        title: titleController.text,
                                        date: taskDate,
                                        time: '${selectedTime.period == DayPeriod.am ? 'AM' : 'PM'} ${selectedTime.hourOfPeriod.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                        isImportant: isImportant,
                                        isUrgent: isUrgent,
                                        memo: memoController.text,
                                        location: locationController.text,
                                        importance: importanceLevel,
                                        urgency: urgencyLevel,
                                      );

                                      final dateKey = _dateToKey(taskDate);

                                      setState(() {
                                        if (this.tasksByDate.containsKey(dateKey)) {
                                          this.tasksByDate[dateKey]!.add(newTask);
                                        } else {
                                          this.tasksByDate[dateKey] = [newTask];
                                        }
                                      });

                                      Navigator.of(context).pop();

                                      this.setState(() {
                                        this.selectedDate = taskDate;
                                        this.calculateProgress();
                                      });

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('일정이 저장되었습니다')),
                                      );
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

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

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