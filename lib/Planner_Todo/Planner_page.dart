import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner_Todo/task_events.dart';
import 'package:momentum_planner/Planner_Todo/task_todo.dart';
import 'package:momentum_planner/Planner_Todo/Event_form.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({Key? key}) : super(key: key);

  @override
  _PlannerPageState createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  // Current date and selected date
  DateTime currentDate = DateTime.now();
  DateTime selectedDate = DateTime.now();

  // Current month and year for the calendar
  DateTime currentMonth = DateTime.now();

  // Toggle between planner and to-do list view
  bool showPlanner = true;

  // Lists to store tasks and events
  List<Task> tasks = [];
  List<PlannerEvent> events = [];

  // Progress tracking
  int completedTasks = 0;
  int totalTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // In a real app, you would load data from a database
    // For this demo, let's add some example data
    tasks = [
      Task(
        id: '1',
        title: 'Running',
        date: DateTime.now(),
        priority: 2,
        urgency: 2,
        note: 'Today is the marathon~ check it out',
      ),
      Task(
        id: '2',
        title: 'lunch',
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 11, minute: 30),
        endTime: const TimeOfDay(hour: 13, minute: 0),
        priority: 1,
        urgency: 1,
        note: 'yeah ~ go to 식당',
      ),
      Task(
        id: '3',
        title: 'Study',
        date: DateTime.now(),
        startTime: const TimeOfDay(hour: 13, minute: 15),
        endTime: const TimeOfDay(hour: 16, minute: 0),
        priority: 3,
        urgency: 2,
        note: 'yeah ~ go to 식당',
      ),
    ];

    // Calculate progress
    totalTasks = tasks.length;
    completedTasks = tasks.where((task) => task.isCompleted).length;

    // Create events from tasks for the planner view
    _createEventsFromTasks();

    setState(() {});
  }

  void _createEventsFromTasks() {
    events = [];

    // Generate events for today's tasks that have time information
    for (var task in tasks.where((t) =>
    isSameDay(t.date, selectedDate) &&
        t.startTime != null &&
        t.endTime != null)) {

      events.add(PlannerEvent(
        id: task.id,
        title: task.title,
        date: task.date,
        startTime: task.startTime!,
        endTime: task.endTime!,
        note: task.note,
        location: task.location,
        color: _getColorForTask(task),
      ));
    }
  }

  Color _getColorForTask(Task task) {
    // Assign colors based on priority or other criteria
    if (task.title.contains('lunch')) {
      return Colors.green.shade100;
    } else if (task.title.contains('Study')) {
      return Colors.purple.shade100;
    } else {
      return Colors.orange.shade100;
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _changeMonth(int direction) {
    setState(() {
      // Add or subtract months
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + direction,
        1,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
      _createEventsFromTasks();
    });
  }

  void _toggleView() {
    setState(() {
      showPlanner = !showPlanner;
    });
  }

  void _addTask() {
    // Show dialog to add a new task
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        onSave: (task) {
          setState(() {
            tasks.add(task);
            totalTasks = tasks.length;
            completedTasks = tasks.where((task) => task.isCompleted).length;
            _createEventsFromTasks();
          });
        },
        selectedDate: selectedDate,
      ),
    );
  }

  void _addEvent() {
    if (tasks.isEmpty) {
      // Show message that we need tasks to create events
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add tasks first to create events')),
      );
      return;
    }

    // Show dialog to create planner event from tasks
    showDialog(
      context: context,
      builder: (context) => EventFormDialog(
        tasks: tasks.where((t) => isSameDay(t.date, selectedDate)).toList(),
        onSave: (event) {
          setState(() {
            events.add(event);
          });
        },
        selectedDate: selectedDate,
      ),
    );
  }

  void _toggleTaskCompletion(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      completedTasks = tasks.where((task) => task.isCompleted).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Calendar header
            _buildCalendarHeader(),

            // Week days and dates
            _buildWeekCalendar(),

            // Progress bar
            _buildProgressBar(),

            // Toggle switch
            _buildViewToggle(),

            // Planner or Todo list content
            Expanded(
              child: showPlanner
                  ? _buildPlannerView()
                  : _buildTodoListView(),
            ),

            // Bottom navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
            onPressed: () {
              // Back button functionality
            },
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '${currentMonth.year}년 ${currentMonth.month}월',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    // Calculate the start of the week (Sunday) for the selected date
    final DateTime weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );

    return Column(
      children: [
        // Day names (일, 월, 화, 수, 목, 금, 토)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Expanded(child: Center(child: Text('일', style: TextStyle(color: Colors.red)))),
              Expanded(child: Center(child: Text('월'))),
              Expanded(child: Center(child: Text('화'))),
              Expanded(child: Center(child: Text('수'))),
              Expanded(child: Center(child: Text('목'))),
              Expanded(child: Center(child: Text('금'))),
              Expanded(child: Center(child: Text('토'))),
            ],
          ),
        ),

        // Dates of the week
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = weekStart.add(Duration(days: index));
              final isSelected = isSameDay(date, selectedDate);

              return GestureDetector(
                onTap: () => _selectDate(date),
                child: Container(
                  width: (MediaQuery.of(context).size.width - 32) / 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.purple.shade200 : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tasks.any((t) => isSameDay(t.date, date))
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final double progress = totalTasks > 0 ? completedTasks / totalTasks : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Progress now',
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text('${(progress * 100).toInt()}%'),
            ],
          ),
          const SizedBox(height: 4),
          Text('$completedTasks/$totalTasks Task Complete'),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            showPlanner ? 'My Today Planner' : 'My Today Tasks',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Switch(
            value: showPlanner,
            onChanged: (value) => _toggleView(),
            activeColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerView() {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No events for today'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addEvent,
              child: const Text('Add Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
            ),
          ],
        ),
      );
    }

    // Sort events by start time
    events.sort((a, b) {
      final aTime = a.startTime.hour * 60 + a.startTime.minute;
      final bTime = b.startTime.hour * 60 + b.startTime.minute;
      return aTime.compareTo(bTime);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];

        // Format time to display
        final startTimeStr = '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}';
        final endTimeStr = '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AM ${startTimeStr}',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('AM $startTimeStr - $endTimeStr'),
                    ],
                  ),
                  if (event.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(event.note!),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTodoListView() {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No tasks for today'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
            ),
          ],
        ),
      );
    }

    // Filter tasks for today and yesterday
    final todayTasks = tasks.where((t) => isSameDay(t.date, selectedDate)).toList();
    final yesterdayTasks = tasks.where((t) {
      final yesterday = selectedDate.subtract(const Duration(days: 1));
      return isSameDay(t.date, yesterday);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (todayTasks.isNotEmpty)
          ..._buildTasksList('My Today Tasks', todayTasks),

        if (yesterdayTasks.isNotEmpty) ...[
          const SizedBox(height: 24),
          ..._buildTasksList('My yesterday Tasks', yesterdayTasks),
        ],
      ],
    );
  }

  List<Widget> _buildTasksList(String title, List<Task> tasksList) {
    return [
      const SizedBox(height: 16),
      ...tasksList.map((task) => _buildTaskItem(task)),
    ];
  }

  Widget _buildTaskItem(Task task) {
    // Format time to display if available
    String timeStr = '';
    if (task.startTime != null && task.endTime != null) {
      final startTimeStr = '${task.startTime!.hour.toString().padLeft(2, '0')}:${task.startTime!.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${task.endTime!.hour.toString().padLeft(2, '0')}:${task.endTime!.minute.toString().padLeft(2, '0')}';
      timeStr = 'AM $startTimeStr - PM $endTimeStr';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getColorForTask(task),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => _toggleTaskCompletion(task),
                activeColor: Colors.purple,
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
          if (task.note != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Text(
                task.note!,
                style: TextStyle(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.book_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}