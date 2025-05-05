import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:momentum_planner/bottom_nav.dart';

import '../models/event.dart';
import '../models/todo_item.dart';
import '../dialogs/event_dialog.dart';
import '../dialogs/todo_dialog.dart';
import '../widgets/header.dart';
import '../widgets/section_header.dart';
import '../widgets/event_card.dart';
import '../widgets/todo_card.dart';

class CalendarScreen extends StatefulWidget {
  final String userId;
  const CalendarScreen({Key? key, required this.userId}) : super(key: key); // 추가

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Event>> _events = {};
  Map<DateTime, List<TodoItem>> _todoItems = {};
  String? _currentUserId; // 받은 userId 저장용

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;
    print('✅ CalendarScreen에서 받은 userId = $_currentUserId');
    _loadEventsFromFirebase();
    _loadTodosFromFirebase();
  }

  void _loadEventsFromFirebase() {
    FirebaseFirestore.instance
        .collection('events')
        .where('userId',isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot){
      Map<DateTime, List<Event>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final startDate = DateTime.parse(data['startDate']);
        final endDate = DateTime.parse(data['endDate']);

        final startTime = data['startTime'] != null
            ? TimeOfDay(hour: data['startTime']['hour'], minute: data['startTime']['minute'])
            : null;
        final endTime = data['endTime'] != null
            ? TimeOfDay(hour: data['endTime']['hour'], minute: data['endTime']['minute'])
            : null;

        final event = Event(
          userId: data['userId'],
          id: doc.id,
          title: data['title'],
          description: data['description'] ?? '',
          startDate: startDate,
          endDate: endDate,
          startTime: startTime,
          endTime: endTime,
          memo: data['memo'] ?? '',
          location: data['location'] ?? '',
          isRepeating: data['isRepeating'] ?? false,
          repeatOption: data['repeatOption'],
          repeatDays: data['repeatDays'] != null ? List<int>.from(data['repeatDays']) : null,
          repeatCustomDays: data['repeatCustomDays'],
          isAllDay: data['isAllDay'] ?? false,
          reminder: data['reminder'],
        );

        // Use startDate for organizing events instead of a 'date' field
        final key = DateTime(startDate.year, startDate.month, startDate.day);
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
    FirebaseFirestore.instance
        .collection('todos')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      Map<DateTime, List<TodoItem>> todos = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = DateTime.parse(data['date']);

        final startTime = data['startTime'] != null
            ? TimeOfDay(hour: data['startTime']['hour'], minute: data['startTime']['minute'])
            : null;
        final endTime = data['endTime'] != null
            ? TimeOfDay(hour: data['endTime']['hour'], minute: data['endTime']['minute'])
            : null;

        final todo = TodoItem(
          userId: data['userId'],
          id: doc.id,
          title: data['title'],
          date: date, // date 속성 추가
          startTime: startTime,
          endTime: endTime,
          memo: data['memo'] ?? '',
          location: data['location'] ?? '',
          isRepeating: data['isRepeating'] ?? false,
          repeatOption: data['repeatOption'],
          repeatDays: data['repeatDays'] != null ? List<int>.from(data['repeatDays']) : null,
          repeatCustomDays: data['repeatCustomDays'],
          reminder: data['reminder'],
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
    print("선택된 날짜: ${day.toString()}");

    final key = DateTime(day.year, day.month, day.day);
    final todos = _todoItems[key] ?? [];

    print("해당 날짜의 할 일 개수: ${todos.length}");
    return todos;
  }

  // In CalendarScreen class
  void _addEvent(Event event) async {
    final startTimeMap = !event.isAllDay && event.startTime != null ? {
      'hour': event.startTime!.hour,
      'minute': event.startTime!.minute,
    } : null;

    final endTimeMap = !event.isAllDay && event.endTime != null ? {
      'hour': event.endTime!.hour,
      'minute': event.endTime!.minute,
    } : null;

    final eventDate = {
      'userId': _currentUserId,
      'title': event.title,
      'description': event.description,
      'startDate': event.startDate.toIso8601String(),
      'endDate': event.endDate.toIso8601String(),
      'startTime': startTimeMap,
      'endTime': endTimeMap,
      'memo': event.memo,
      'location': event.location,
      'isRepeating': event.isRepeating,
      'repeatOption': event.repeatOption,
      'repeatDays': event.repeatDays,
      'repeatCustomDays': event.repeatCustomDays,
      'isAllDay': event.isAllDay,
      'reminder': event.reminder,
    };

    final docRef = await FirebaseFirestore.instance.collection('events').add(eventDate);

    setState(() {
      final key = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      final newEvent = event.copyWith(id: docRef.id);

      if (_events[key] != null) {
        _events[key]!.add(newEvent);
      } else {
        _events[key] = [newEvent];
      }
    });
  }

  void _addTodo(TodoItem todo) async {
    try {
      final startTimeMap = !todo.isAllDay && todo.startTime != null ? {
        'hour': todo.startTime!.hour,
        'minute': todo.startTime!.minute,
      } : null;

      final endTimeMap = !todo.isAllDay && todo.endTime != null ? {
        'hour': todo.endTime!.hour,
        'minute': todo.endTime!.minute,
      } : null;

      final todoDate = {
        'userId': _currentUserId,
        'title': todo.title,
        'date': todo.date.toIso8601String(),
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'memo': todo.memo,
        'location': todo.location ?? '',
        'isRepeating': todo.isRepeating,
        'repeatOption': todo.repeatOption,
        'repeatDays': todo.repeatDays,
        'repeatCustomDays': todo.repeatCustomDays,
        'reminder': todo.reminder,
        'isCompleted': false,
      };

      final docRef = await FirebaseFirestore.instance.collection('todos').add(todoDate);

      setState(() {
        final key = DateTime(todo.date.year, todo.date.month, todo.date.day);
        final newTodo = todo.copyWith(id: docRef.id);

        if (_todoItems[key] != null) {
          _todoItems[key]!.add(newTodo);
        } else {
          _todoItems[key] = [newTodo];
        }
      });
    } catch (e) {
      print("Error adding todo: $e");
    }
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => EventDialog(
        currentUserId: _currentUserId ?? 'unknown',
        selectedDay: _selectedDay,
        onSave: _addEvent,
        isEditing: false,
      ),
    );
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => TodoDialog(
        currentUserId: _currentUserId ?? 'unknown',
        selectedDay: _selectedDay,
        onSave: _addTodo,
        isEditing: false,
      ),
    );
  }

  void _showEventDetailsDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => EventDialog(
        currentUserId: _currentUserId ?? 'unknown',
        selectedDay: event.startDate,
        event: event,
        onSave: _updateEvent,
        onDelete: _deleteEvent, // 삭제 콜백 추가
        isEditing: true, // 수정 모드임을 나타냄
      ),
    );
  }

  void _showTodoDetailsDialog(TodoItem todo) {
    showDialog(
      context: context,
      builder: (context) => TodoDialog(
        currentUserId: _currentUserId ?? 'unknown',
        selectedDay: todo.date,
        todo: todo,
        onSave: _updateTodo,
        onDelete: _deleteTodo, // 삭제 콜백 추가
        isEditing: true, // 수정 모드임을 나타냄
      ),
    );
  }

  void _updateEvent(Event event) async {
    try {
      final startTimeMap = !event.isAllDay && event.startTime != null ? {
        'hour': event.startTime!.hour,
        'minute': event.startTime!.minute,
      } : null;

      final endTimeMap = !event.isAllDay && event.endTime != null ? {
        'hour': event.endTime!.hour,
        'minute': event.endTime!.minute,
      } : null;

      await FirebaseFirestore.instance.collection('events').doc(event.id).update({
        'title': event.title,
        'description': event.description,
        'startDate': event.startDate.toIso8601String(),
        'endDate': event.endDate.toIso8601String(),
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'memo': event.memo,
        'location': event.location,
        'isRepeating': event.isRepeating,
        'repeatOption': event.repeatOption,
        'repeatDays': event.repeatDays,
        'repeatCustomDays': event.repeatCustomDays,
        'isAllDay': event.isAllDay,
        'reminder': event.reminder,
      });

      print('Event updated successfully');
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  Future<void> deleteEvent(Event event) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
      print('Event deleted successfully');
    } catch (e) {
      print('Error deleting event: $e');
    }
  }

  void _updateTodo(TodoItem todo) async {
    try {
      final startTimeMap = !todo.isAllDay && todo.startTime != null ? {
        'hour': todo.startTime!.hour,
        'minute': todo.startTime!.minute,
      } : null;

      final endTimeMap = !todo.isAllDay && todo.endTime != null ? {
        'hour': todo.endTime!.hour,
        'minute': todo.endTime!.minute,
      } : null;

      await FirebaseFirestore.instance.collection('todos').doc(todo.id).update({
        'title': todo.title,
        'date': todo.date.toIso8601String(),
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'memo': todo.memo,
        'location': todo.location,
        'isRepeating': todo.isRepeating,
        'repeatOption': todo.repeatOption,
        'repeatDays': todo.repeatDays,
        'repeatCustomDays': todo.repeatCustomDays,
        'isAllDay': todo.isAllDay,
        'reminder': todo.reminder,
      });

      print('Todo updated successfully');
    } catch (e) {
      print('Error updating todo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('CalendarScreen: userId = ${widget.userId}');

    return Scaffold(
      backgroundColor: Colors.white,
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
      bottomNavigationBar: BottomNav(initialIndex: 0, userId: _currentUserId ?? 'unknown'),
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
                  'assets/svgs/arrow-left-svgrepo-com.svg', // 얇은 왼쪽 화살표 SVG 파일
                  width: 12.0,
                  height: 27.0,
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
              SizedBox(width: 18,),
              Text(
                intl.DateFormat('M').format(_focusedDay), // 현재 월 표시
                style: TextStyle(
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenSansBold',
                ),
              ),
              SizedBox(width: 18,),
              IconButton(
                icon: SvgPicture.asset(
                  'assets/svgs/arrow-right-svgrepo-com.svg', // 얇은 오른쪽 화살표 SVG 파일
                  width: 12.0,
                  height: 27.0,
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
          SizedBox(height: 15,),
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
              setState(() {
                _focusedDay = focusedDay;
              });
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

              outsideDaysVisible: false,
              markersMaxCount: 1,
              markersAnchor: 0.7,
            ),
            daysOfWeekHeight: 36.0,
            rowHeight: 48.0,

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.black),
              weekendStyle: TextStyle(color: Colors.black),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                // 요일 텍스트를 한 글자로 표시
                String text;
                if (day.weekday == DateTime.sunday || day.weekday == DateTime.saturday) {
                  text = "S"; // 일요일과 토요일은 "S"
                } else {
                  text = intl.DateFormat.E().format(day)[0]; // 나머지 요일은 첫 글자만
                }

                // 요일 색상 설정
                Color color;
                if (day.weekday == DateTime.sunday) {
                  color = Colors.red; // 일요일 빨간색
                } else if (day.weekday == DateTime.saturday) {
                  color = Colors.blue; // 토요일 파란색
                } else {
                  color = Colors.black; // 나머지 요일 검은색
                }

                return Center(
                  child: Text(
                    text,
                    style: TextStyle(color: color),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                // 현재 달의 날짜 스타일
                return Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(color: Colors.black),
                  ),
                );
              },
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
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
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return GestureDetector(
              onTap: () => _showEventDetailsDialog(event),
              child: EventCard(
                event: event,
                onEdit: () => _showEventDetailsDialog(event),
                onDelete: () => _deleteEvent(event),
                onMorePressed: () => _showEventDetailsDialog(event),
              ),
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
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return TodoCard(
              todo: todo,
              onStatusChanged: (dynamic value) {
                bool newStatus;

                if (value is bool) {
                  newStatus = value;
                } else {
                  newStatus = !todo.isCompleted;
                }

                FirebaseFirestore.instance.collection('todos').doc(todo.id).update({
                  'isCompleted': newStatus,
                }).then((_) { // Firestore 업데이트 성공 후 로컬 상태 업데이트
                  setState(() {
                    final key = DateTime(todo.date.year, todo.date.month, todo.date.day);
                    if (_todoItems.containsKey(key)) {
                      final index = _todoItems[key]!.indexWhere((item) => item.id == todo.id);
                      if (index != -1) {
                        _todoItems[key]![index] = todo.copyWith(isCompleted: newStatus);
                      }
                    }
                  });
                }).catchError((error) {
                  print("Error updating todo: $error");
                  // 에러 처리 로직 (예: 스낵바 표시) 추가
                });
              },
              onEdit: () => _showTodoDetailsDialog(todo),
              onDelete: () => _deleteTodo(todo),
              onMorePressed: () => _showTodoDetailsDialog(todo),
            );
          },
        ),
      ],
    );
  }

  void _deleteEvent(Event event) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
      print('Event deleted successfully');
      Navigator.pop(context); // 다이얼로그 닫기
    } catch (e) {
      print('Error deleting event: $e');
    }
    // 삭제 후 상태 업데이트 (예: 화면 갱신)
    setState(() {
      final key = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      _events[key]?.removeWhere((e) => e.id == event.id);
    });
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(todo.id).delete();
      print('Todo deleted successfully');
      Navigator.pop(context); // 다이얼로그 닫기
    } catch (e) {
      print('Error deleting todo: $e');
    }
    // 삭제 후 상태 업데이트 (예: 화면 갱신)
    setState(() {
      final key = DateTime(todo.date.year, todo.date.month, todo.date.day);
      _events[key]?.removeWhere((e) => e.id == todo.id);
    });
  }
}