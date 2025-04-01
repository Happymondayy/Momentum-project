import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/event.dart';
import '../models/todo_item.dart';
import '../dialogs/event_dialog.dart';
import '../dialogs/todo_dialog.dart';
import '../widgets/header.dart';
import '../widgets/section_header.dart';
import '../widgets/event_card.dart';
import '../widgets/todo_card.dart';
import '../widgets/footer.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Event>> _events = {};
  Map<DateTime, List<TodoItem>> _todoItems = {};

  @override
  void initState() {
    super.initState();
    _loadEventsFromFirebase();
    _loadTodosFromFirebase();
  }

  void _loadEventsFromFirebase() {
    FirebaseFirestore.instance.collection('events').snapshots().listen((snapshot) {
      Map<DateTime, List<Event>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);
        final startTime = data['startTime'] != null
            ? TimeOfDay(hour: data['startTime']['hour'], minute: data['startTime']['minute'])
            : null;
        final endTime = data['endTime'] != null
            ? TimeOfDay(hour: data['endTime']['hour'], minute: data['endTime']['minute'])
            : null;

        final event = Event(
          id: doc.id,
          title: data['title'],
          startTime: startTime,
          endTime: endTime,
          memo: data['memo'],
          isRepeating: data['isRepeating'] ?? false,
        );

        final key = DateTime(date.year, date.month, date.day);
        if (events[key] != null) {
          events[key]!.add(event);
        } else {
          events[key] = [event];
        }
      }

      setState(() {
        _events = events;
      });
    });
  }

  void _loadTodosFromFirebase() {
    FirebaseFirestore.instance.collection('todos').snapshots().listen((snapshot) {
      Map<DateTime, List<TodoItem>> todos = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);
        final time = data['time'] != null
            ? TimeOfDay(hour: data['time']['hour'], minute: data['time']['minute'])
            : null;

        final todo = TodoItem(
          id: doc.id,
          title: data['title'],
          time: time,
          memo: data['memo'],
          isRepeating: data['isRepeating'] ?? false,
          isCompleted: data['isCompleted'] ?? false,
        );

        final key = DateTime(date.year, date.month, date.day);
        if (todos[key] != null) {
          todos[key]!.add(todo);
        } else {
          todos[key] = [todo];
        }
      }

      setState(() {
        _todoItems = todos;
      });
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  List<TodoItem> _getTodosForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _todoItems[key] ?? [];
  }

  void _addEvent(String title, DateTime date, TimeOfDay? startTime,
      TimeOfDay? endTime, String memo, bool isRepeating, bool isAllDay) async {
    if (title.isEmpty) return;

    final startTimeMap = startTime != null ? {
      'hour': startTime.hour,
      'minute': startTime.minute,
    } : null;

    final endTimeMap = endTime != null ? {
      'hour': endTime.hour,
      'minute': endTime.minute,
    } : null;

    await FirebaseFirestore.instance.collection('events').add({
      'title': title,
      'date': date.toIso8601String(),
      'startTime': isAllDay ? null : startTimeMap,
      'endTime': isAllDay ? null : endTimeMap,
      'memo': memo,
      'isRepeating': isRepeating,
    });
  }

  void _addTodo(String title, DateTime date, TimeOfDay time, String memo, bool isRepeating) async {
    if (title.isEmpty) return;

    final timeMap = {
      'hour': time.hour,
      'minute': time.minute,
    };

    await FirebaseFirestore.instance.collection('todos').add({
      'title': title,
      'date': date.toIso8601String(),
      'time': timeMap,
      'memo': memo,
      'isRepeating': isRepeating,
      'isCompleted': false,
    });
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => EventDialog(
        selectedDay: _selectedDay,
        onSave: _addEvent,
      ),
    );
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => TodoDialog(
        selectedDay: _selectedDay,
        onSave: _addTodo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 헤더는 항상 상단에 고정
            Header(
              focusedDay: _focusedDay,
              onMenuPressed: () {
                // Open settings
              },
            ),
            // 나머지 컨텐츠는 스크롤 가능하게
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCalendar(),
                    _buildScheduleSection(),
                    _buildTodoSection(),
                    // 푸터와 하단 여백 추가
                    SizedBox(height: 70), // 푸터 높이보다 약간 크게
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // 푸터는 하단에 고정
      bottomNavigationBar: Footer(
        onCalendarPressed: () {},
        onListPressed: () {},
        onEditPressed: () {},
        onChatPressed: () {},
      ),
    );
  }


  Widget _buildCalendar() {
    return Column(
      children: [
        Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ // 커스텀 헤더
          IconButton(
            icon: SvgPicture.asset(
              '- assets/svgs/caret-left-svgrepo-com.svg', // 얇은 왼쪽 화살표 SVG 파일
              width: 15.0,
              height: 40.0,
              color: Colors.red,
            ),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                _focusedDay.year,
                _focusedDay.month - 1,
                _focusedDay.day,
              );
             });
            },
          ),
          SizedBox(width: 13,),
          Text(
            DateFormat('M').format(_focusedDay), // 현재 월 표시
            style: TextStyle(
            fontSize: 30.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenSansBold',
            ),
          ),
          SizedBox(width: 13,),
          IconButton(
            icon: SvgPicture.asset(
              '- assets/svgs/caret-right-svgrepo-com.svg', // 얇은 오른쪽 화살표 SVG 파일
              width: 15.0,
              height: 40.0,
            ),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                _focusedDay.year,
                _focusedDay.month + 1,
                _focusedDay.day,
                );
              });
            },
          ),
        ],
      ),
    TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      headerVisible: false, // 커스텀 헤더를 사용하기 위해 기본 헤더는 숨김

      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      eventLoader: _getEventsForDay,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.deepPurple.shade100,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.deepPurple.shade300,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Colors.deepPurple.shade200,
          shape: BoxShape.circle,
        ),
        weekendTextStyle: TextStyle(color: Colors.red),
        outsideTextStyle: TextStyle(color: Colors.grey),
      ),

      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.black),
        weekendStyle: TextStyle(color: Colors.red),
      ),
      calendarBuilders: CalendarBuilders(
        dowBuilder: (context, day) {
          final text = DateFormat.E().format(day)[0];
          if (day.weekday == DateTime.sunday || day.weekday == DateTime.saturday) {
            Color color = day.weekday == DateTime.sunday ? Colors.red : Colors.blue;
            return Center(
              child: Text(
                text,
                style: TextStyle(color: color),
              ),
            );
          }
          return null;
        },
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.shade300,
                ),
              ),
            );
          }
          return null;
        },
      ),
    ),
    ]
    );
  }

  Widget _buildScheduleSection() {
    final events = _getEventsForDay(_selectedDay);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: '일정',
          onAddPressed: _showAddEventDialog,
        ),
        events.isEmpty
            ? Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('오늘 일정이 없습니다.')),
        )
            : ListView.builder(
          physics: NeverScrollableScrollPhysics(), // 중요: 개별 스크롤 비활성화
          shrinkWrap: true, // 중요: 컨텐츠 크기만큼만 차지
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return EventCard(
              event: event,
              onMorePressed: () {
                // Show options
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodoSection() {
    final todos = _getTodosForDay(_selectedDay);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'To-do list',
          onAddPressed: _showAddTodoDialog,
        ),
        todos.isEmpty
            ? Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('오늘 할 일이 없습니다.')),
        )
            : ListView.builder(
          physics: NeverScrollableScrollPhysics(), // 중요: 개별 스크롤 비활성화
          shrinkWrap: true, // 중요: 컨텐츠 크기만큼만 차지
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return TodoCard(
              todo: todo,
              onStatusChanged: (value) {
                FirebaseFirestore.instance.collection('todos').doc(todo.id).update({
                  'isCompleted': value,
                });
              },
              onMorePressed: () {
                // Show options
              },
            );
          },
        ),
      ],
    );
  }
}