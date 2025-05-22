import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:momentum_planner/bottom_nav.dart';

import '../../Planner/DailyPlannerPage.dart';
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
  const CalendarScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Event>> _events = {};
  Map<DateTime, List<TodoItem>> _todoItems = {};
  String? _currentUserId;

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
        try {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();
        final repeatUntil = data['repeatUntil'] != null
            ? (data['repeatUntil'] as Timestamp).toDate()
            : null;

        final startTime = data['startTime'] != null
            ? TimeOfDay(hour: data['startTime']['hour'], minute: data['startTime']['minute'])
            : null;
        final endTime = data['endTime'] != null
            ? TimeOfDay(hour: data['endTime']['hour'], minute: data['endTime']['minute'])
            : null;

        final event = Event(
          userId: data['userId'],
          id: doc.id,
          title: data['title'] ?? '제목 없음',
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
          isReminderScheduled: data['isReminderScheduled'] ?? false,
          repeatUntil: repeatUntil,
          parentEventId: data['parentEventId'],
        );

        // Use startDate for organizing events instead of a 'date' field
        final key = DateTime(startDate.year, startDate.month, startDate.day);
        if (events[key] != null) {
          events[key]!.add(event);
        } else {
          events[key] = [event];
        }
      } catch (e) {
          print('이벤트 로딩 오류: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _events = events;
        });
      }
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
        try {
          final data = doc.data();

          // null 체크 추가
          if (data['date'] == null) continue;

          final date = DateTime.parse(data['date']);
          final isRepeating = data['isRepeating'] ?? false;

          final baseTodo = _createTodoFromData(data, doc.id, date);
          _addTodoToMap(todos, baseTodo);

          if (isRepeating) {
            final repeatTodos = _generateRepeatTodos(baseTodo, data);
            for (final repeatTodo in repeatTodos) {
              _addTodoToMap(todos, repeatTodo);
            }
          }
        } catch (e) {
          print('투두 로딩 오류: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _todoItems = todos;
        });
      }
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    try {
      final key = DateTime(day.year, day.month, day.day);
      final events = _events[key] ?? [];

      return events;
    } catch (e) {
      print('이벤트 가져오기 오류: $e');
      return [];
    }
  }

  TimeOfDay? _parseTimeStringToTimeOfDay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;

    try {
      // "AM 09:30" 또는 "PM 03:45" 형식 파싱
      if (timeString.contains('AM') || timeString.contains('PM')) {
        bool isAM = timeString.startsWith('AM');
        final timePart = timeString.substring(3).trim();
        final parts = timePart.split(':');

        if (parts.length != 2) return null;

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
      }

      // "09:30" 형식 파싱
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          int hour = int.parse(parts[0].trim());
          int minute = int.parse(parts[1].trim());
          return TimeOfDay(hour: hour, minute: minute);
        }
      }

      return null;
    } catch (e) {
      print('시간 파싱 오류: $e (입력: $timeString)');
      return null;
    }
  }

  List<TodoItem> _getTodosForDay(DateTime day) {
    try {
      print("선택된 날짜: ${day.toString()}");
      final key = DateTime(day.year, day.month, day.day);
      final todos = _todoItems[key] ?? [];
      print("해당 날짜의 할 일 개수: ${todos.length}");
      return todos;
    } catch (e) {
      print('투두 가져오기 오류: $e');
      return [];
    }
  }

  TodoItem _createTodoFromData(Map<String, dynamic> data, String docId, DateTime date) {
    try {
      final startTime = data['startTime'] != null
          ? TimeOfDay(
          hour: data['startTime']['hour'] ?? 0,
          minute: data['startTime']['minute'] ?? 0
      )
          : null;
      final endTime = data['endTime'] != null
          ? TimeOfDay(
          hour: data['endTime']['hour'] ?? 0,
          minute: data['endTime']['minute'] ?? 0
      )
          : null;

      return TodoItem(
        userId: data['userId'] ?? _currentUserId ?? '',
        id: docId,
        title: data['title'] ?? '제목 없음',
        date: date,
        startTime: startTime,
        endTime: endTime,
        importance: data['importance'] ?? 3,
        urgency: data['urgency'] ?? 3,
        memo: data['memo'] ?? '',
        location: data['location'] ?? '',
        isRepeating: data['isRepeating'] ?? false,
        repeatOption: data['repeatOption'],
        repeatDays: data['repeatDays'] != null ? List<int>.from(data['repeatDays']) : null,
        repeatCustomDays: data['repeatCustomDays'],
        isAllDay: data['isAllDay'] ?? false,
        reminder: data['reminder'],
        isCompleted: data['isCompleted'] ?? false,
      );
    } catch (e) {
      print('TodoItem 생성 오류: $e');
      // 기본값으로 TodoItem 반환
      return TodoItem(
        userId: _currentUserId ?? '',
        id: docId,
        title: '제목 없음',
        date: date,
        startTime: null,
        endTime: null,
        importance: 3,
        urgency: 3,
        memo: '',
        location: '',
        isRepeating: false,
        repeatOption: null,
        repeatDays: null,
        repeatCustomDays: null,
        isAllDay: false,
        reminder: null,
        isCompleted: false,
      );
    }
  }

  void _addEvent(Event event) async {
    try {
      final startTimeMap = !event.isAllDay && event.startTime != null ? {
        'hour': event.startTime!.hour,
        'minute': event.startTime!.minute,
      } : null;

      final endTimeMap = !event.isAllDay && event.endTime != null ? {
        'hour': event.endTime!.hour,
        'minute': event.endTime!.minute,
      } : null;

      final eventDate = {
        'userId': _currentUserId ?? '',
        'title': event.title ?? '제목 없음',
        'description': event.description ?? '',
        'startDate': event.startDate,
        'endDate': event.endDate,
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'memo': event.memo ?? '',
        'location': event.location ?? '',
        'isRepeating': event.isRepeating,
        'repeatOption': event.repeatOption,
        'repeatDays': event.repeatDays,
        'repeatCustomDays': event.repeatCustomDays,
        'isAllDay': event.isAllDay,
        'reminder': event.reminder,
        'isReminderScheduled': event.isReminderScheduled,
        'repeatUntil': event.repeatUntil,
        'parentEventId': event.id,
      };

      await FirebaseFirestore.instance.collection('events').add(eventDate);
    } catch (e) {
      print("이벤트 추가 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이벤트 추가 중 오류가 발생했습니다.')),
        );
      }
    }
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
        'userId': _currentUserId ?? '',
        'title': todo.title ?? '제목 없음',
        'date': todo.date.toIso8601String(),
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'memo': todo.memo ?? '',
        'location': todo.location ?? '',
        'isRepeating': todo.isRepeating,
        'repeatOption': todo.repeatOption,
        'repeatDays': todo.repeatDays,
        'repeatCustomDays': todo.repeatCustomDays,
        'reminder': todo.reminder,
        'isCompleted': false,
      };

      await FirebaseFirestore.instance.collection('todos').add(todoDate);
    } catch (e) {
      print("투두 추가 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('투두 추가 중 오류가 발생했습니다.')),
        );
      }
    }
  }




  // 반복 투두 생성 함수
  List<TodoItem> _generateRepeatTodos(TodoItem baseTodo, Map<String, dynamic> data) {
    List<TodoItem> repeatTodos = [];
    final repeatOption = data['repeatOption'];
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 365)); // 1년간 반복 생성

    DateTime currentDate = baseTodo.date.add(Duration(days: 1));

    while (currentDate.isBefore(endDate)) {
      bool shouldAdd = false;

      switch (repeatOption) {
        case '매일':
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case '매주':
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: 7));
          break;
        case '매달':
          shouldAdd = true;
          currentDate = DateTime(currentDate.year, currentDate.month + 1, baseTodo.date.day);
          break;
        case '매년':
          shouldAdd = true;
          currentDate = DateTime(currentDate.year + 1, baseTodo.date.month, baseTodo.date.day);
          break;
        case '매요일':
          final repeatDays = data['repeatDays'] != null ? List<int>.from(data['repeatDays']) : <int>[];
          if (repeatDays.contains(currentDate.weekday - 1)) {
            shouldAdd = true;
          }
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case '기타':
          final customDays = data['repeatCustomDays'] ?? 1;
          shouldAdd = true;
          currentDate = currentDate.add(Duration(days: customDays));
          break;
        default:
          currentDate = currentDate.add(Duration(days: 1));
      }

      if (shouldAdd) {
        final repeatTodo = baseTodo.copyWith(
          id: '${baseTodo.id}_${currentDate.millisecondsSinceEpoch}',
          date: currentDate,
        );
        repeatTodos.add(repeatTodo);
      }
    }

    return repeatTodos;
  }


  // 투두를 맵에 추가하는 헬퍼 함수
  void _addTodoToMap(Map<DateTime, List<TodoItem>> todos, TodoItem todo) {
    final key = DateTime(todo.date.year, todo.date.month, todo.date.day);
    if (todos[key] != null) {
      todos[key]!.add(todo);
    } else {
      todos[key] = [todo];
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
        onDelete: _deleteEvent,
        isEditing: true,
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
        onDelete: _deleteTodo,
        isEditing: true,
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
        'startDate': event.startDate,
        'endDate': event.endDate,
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
        'isReminderScheduled': event.isReminderScheduled,
        'repeatUntil': event.repeatUntil,
        'parentEventId': event.parentEventId,
      });

      print('Event updated successfully');
      Navigator.pop(context); // Close the dialog
    } catch (e) {
      print('Error updating event: $e');
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
      Navigator.pop(context); // Close the dialog
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
                onDelete: _deleteEvent,
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
                });
                // No need to update state here as the Firestore listener will handle it
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

  // calendar_screen에서 사용할 _deleteEvent 함수
  void _deleteEvent(Event event, String deleteType) async {
    try {
      switch (deleteType) {
        case 'single': // 단일 일정 삭제(반복 일정이 아닌 경우)
          await _deleteThis(event);
          break;
      }

      // 상태 업데이트
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error deleting event: $e");
      // 에러는 dialog에서 처리하므로 여기서는 다시 throw
      rethrow;
    }
  }

  //단일 일정 삭제(반복 일정이 아닌 경우)
  Future<void> _deleteThis(Event event) async{
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .delete();

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _deleteTodo(TodoItem todo) async {
    try {
      // Firestore에서 이벤트 삭제
      await FirebaseFirestore.instance.collection('todos').doc(todo.id).delete();

      // 상태 업데이트 - 로컬 상태도 즉시 업데이트
      if (mounted) {
        setState(() {});

        // 삭제 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정이 삭제되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error deleting event: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 삭제 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}