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
import 'dart:math';

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
    print('=== 이벤트 불러오기 시작 ===');

    // _currentUserId가 null인 경우 조기 반환
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      print('현재 사용자 ID가 null이거나 비어있습니다.');
      if (mounted) {
        setState(() {
          _events = {}; // 빈 맵으로 초기화
        });
      }
      return;
    }

    print('현재 사용자 ID: $_currentUserId');

    FirebaseFirestore.instance
        .collection('events')
        .where('userId', isEqualTo: _currentUserId!)
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      print('Firestore 스냅샷 받음: ${snapshot.docs.length}개 문서');

      Map<DateTime, List<Event>> events = {};

      for (var doc in snapshot.docs) {
        try {
          print('문서 처리 중: ${doc.id}');
          final data = doc.data();

          // Event.fromMap을 사용하여 이벤트 생성
          final event = Event.fromMap(data, _currentUserId!, doc.id);

          print('이벤트 생성 완료: ${event.title}, 장기일정: ${event.isLongTerm}');

          // 이벤트를 날짜별로 분류
          DateTime displayDate;

          if (event.isLongTerm.isNotEmpty && event.term != null) {
            // 장기 일정인 경우: 시작일에 term 일수를 더해서 표시할 날짜 결정
            displayDate = event.startDate.add(Duration(days: event.term!));
          } else {
            // 일반 일정인 경우: 시작일을 표시 날짜로 사용
            displayDate = event.startDate;
          }

          // 날짜 키 생성 (시간 정보 제거)
          final key = DateTime(displayDate.year, displayDate.month, displayDate.day);

          if (events[key] != null) {
            events[key]!.add(event);
          } else {
            events[key] = [event];
          }

        } catch (e, stackTrace) {
          print('이벤트 로딩 오류 - 문서 ${doc.id}: $e');
          print('스택 트레이스: $stackTrace');
          continue;
        }
      }

      print('최종 이벤트 맵 크기: ${events.length}');
      for (var entry in events.entries) {
        print('날짜 ${entry.key}: ${entry.value.length}개 이벤트');
      }

      if (mounted) {
        setState(() {
          _events = events;
        });
        print('상태 업데이트 완료');
      }
    }, onError: (error) {
      print('=== Firestore 리스너 오류 ===');
      print('오류: $error');
    });
  }

  void _loadTodosFromFirebase() {
    FirebaseFirestore.instance
        .collection('todos')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      print('=== Firebase 스냅샷 수신 ===');
      print('문서 개수: ${snapshot.docs.length}');

      Map<DateTime, List<TodoItem>> todos = {};

      for (int i = 0; i < snapshot.docs.length; i++) {
        var doc = snapshot.docs[i];
        print('\n--- 문서 ${i + 1}/${snapshot.docs.length} 처리 중 ---');
        print('문서 ID: ${doc.id}');

        try {
          final data = doc.data();
          print('전체 데이터: $data');

          // 각 필드별 타입 체크
          data.forEach((key, value) {
            print('$key: $value (타입: ${value.runtimeType})');
          });

          // null 체크 추가
          if (data['date'] == null) {
            print('날짜가 null이므로 건너뜀');
            continue;
          }

          final date = DateTime.parse(data['date']);
          final isRepeating = data['isRepeating'] ?? false;

          print('파싱된 날짜: $date');
          print('반복 여부: $isRepeating');

          print('TodoItem 생성 시작...');
          final baseTodo = _createTodoFromData(data, doc.id, date);
          print('TodoItem 생성 완료: ${baseTodo.title}');

          _addTodoToMap(todos, baseTodo);

          if (isRepeating) {
            print('반복 투두 생성 시작...');
            final repeatTodos = _generateRepeatTodos(baseTodo, data);
            print('반복 투두 개수: ${repeatTodos.length}');
            for (final repeatTodo in repeatTodos) {
              _addTodoToMap(todos, repeatTodo);
            }
          }

          print('문서 처리 완료');

        } catch (e, stackTrace) {
          print('❌ 투두 로딩 오류: $e');
          print('스택 트레이스: $stackTrace');
          print('문제가 된 문서 ID: ${doc.id}');
          print('문제가 된 데이터: ${doc.data()}');
          continue;
        }
      }

      print('\n=== 최종 결과 ===');
      print('총 날짜 개수: ${todos.length}');
      todos.forEach((date, todoList) {
        print('${date.toString()}: ${todoList.length}개 투두');
      });

      if (mounted) {
        setState(() {
          _todoItems = todos;
        });
        print('상태 업데이트 완료');
      }
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    try {
      final key = DateTime(day.year, day.month, day.day);
      final events = _events[key] ?? [];

      // 중복 제거: 같은 장기 일정이 여러 번 표시되지 않도록
      final Map<String, Event> uniqueEvents = {};

      for (final event in events) {
        String uniqueKey;
        if (event.isLongTerm != '') {
          // 장기 일정의 경우 원본 ID 사용
          uniqueKey = event.id.split('_day_')[0];
        } else {
          uniqueKey = event.id;
        }

        // 같은 uniqueKey가 없거나, 더 나은 이벤트로 교체
        if (!uniqueEvents.containsKey(uniqueKey)) {
          uniqueEvents[uniqueKey] = event;
        }
      }

      return uniqueEvents.values.toList();
    } catch (e) {
      print('이벤트 가져오기 오류: $e');
      return [];
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
    print('\n_createTodoFromData 시작');
    print('문서 ID: $docId');
    print('날짜: $date');

    try {
      // 시간 파싱
      print('시간 파싱 중...');
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
      print('시간 파싱 완료');

      // 마감일 파싱
      print('마감일 파싱 중...');
      final dueDate = data['dueDate'] != null ? DateTime.parse(data['dueDate']) : null;
      print('마감일 파싱 완료: $dueDate');

      // repeatDays 안전하게 변환
      print('repeatDays 처리 중...');
      List<int>? repeatDaysList;
      if (data['repeatDays'] != null) {
        print('repeatDays 존재함');
        print('repeatDays 타입: ${data['repeatDays'].runtimeType}');
        print('repeatDays 값: ${data['repeatDays']}');

        if (data['repeatDays'] is List) {
          print('List로 인식됨');
          final originalList = data['repeatDays'] as List;
          print('원본 리스트 길이: ${originalList.length}');

          repeatDaysList = [];
          for (int i = 0; i < originalList.length; i++) {
            final item = originalList[i];
            print('인덱스 $i: $item (타입: ${item.runtimeType})');

            if (item is int) {
              repeatDaysList.add(item);
              print('정수로 추가: $item');
            } else {
              final parsed = int.tryParse(item.toString());
              if (parsed != null) {
                repeatDaysList.add(parsed);
                print('파싱하여 추가: $parsed');
              } else {
                print('파싱 실패, 0으로 추가');
                repeatDaysList.add(0);
              }
            }
          }
          print('최종 repeatDaysList: $repeatDaysList');
        } else {
          print('List가 아닌 타입입니다');
        }
      } else {
        print('repeatDays가 null입니다');
      }

      print('TodoItem 객체 생성 중...');
      final todoItem = TodoItem(
        userId: data['userId'] ?? _currentUserId ?? '',
        id: docId,
        title: data['title'] ?? '제목 없음',
        date: date,
        dueDate: dueDate,
        startTime: startTime,
        endTime: endTime,
        importance: data['importance'] ?? 3,
        urgency: data['urgency'] ?? 3,
        memo: data['memo'] ?? '',
        location: data['location'] ?? '',
        isRepeating: data['isRepeating'] ?? false,
        repeatOption: data['repeatOption'],
        repeatDays: repeatDaysList,
        repeatCustomDays: data['repeatCustomDays'],
        isAllDay: data['isAllDay'] ?? false,
        reminder: data['reminder'],
        isCompleted: data['isCompleted'] ?? false,
      );

      print('TodoItem 생성 성공: ${todoItem.title}');
      return todoItem;

    } catch (e, stackTrace) {
      print('❌ _createTodoFromData 오류: $e');
      print('스택 트레이스: $stackTrace');
      print('오류 발생 데이터: $data');

      // 기본값으로 TodoItem 반환
      return TodoItem(
        userId: _currentUserId ?? '',
        id: docId,
        title: '오류 발생 - 제목 없음',
        date: date,
        dueDate: null,
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
        'dueDate': todo.dueDate?.toIso8601String(), // 10마감일 추가
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'importance': todo.importance,
        'urgency': todo.urgency,
        'memo': todo.memo ?? '',
        'location': todo.location ?? '',
        'isRepeating': todo.isRepeating,
        'repeatOption': todo.repeatOption,
        'repeatDays': todo.repeatDays,
        'repeatCustomDays': todo.repeatCustomDays,
        'isAllDay': todo.isAllDay,
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
        'dueDate': todo.dueDate?.toIso8601String(), // 마감일 추가
        'startTime': startTimeMap,
        'endTime': endTimeMap,
        'importance': todo.importance,
        'urgency': todo.urgency,
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
        'createdAt' : DateTime.now(),
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
        'isLongTerm': event.isLongTerm ?? '',
        'term': event.term,
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
      print('업데이트하려는 Event 정보:');
      print('ID: ${event.id}');
      print('제목: ${event.title}');
      print('하루 종일: ${event.isAllDay}');
      print('시작 시간: ${event.startTime}');
      print('종료 시간: ${event.endTime}');

      // toMap() 메서드를 사용하여 일관성 있는 데이터 생성
      final updateData = event.toMap();

      // id는 Firestore 문서 ID이므로 제거
      updateData.remove('id');

      print('Firestore에 저장할 데이터: $updateData');

      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .update(updateData);

      print('Event updated successfully');

      // 다이얼로그 닫기 - 더 안전한 방법
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // 성공 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정이 수정되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      print('Error updating event: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');

      // 에러 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 업데이트 중 오류가 발생했습니다: ${e.toString()}'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              child: Container(
                color: Color(0xF6F6F6F8),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 3), // x:0, y:3 아래 방향으로 그림자
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildCalendar(),
                            SizedBox(height: 18),
                          ],
                        ),
                      ),
                      SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        child:
                          _buildScheduleSection(),
                      ),
                      SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        child:
                        _buildTodoSection(),
                      ),
                      SizedBox(height: 70), // 푸터 높이보다 약간 크게
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ExpandingFAB(
        onSchedulePressed: _showAddEventDialog,
        onTodoPressed: _showAddTodoDialog,
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
              markersAnchor: 1.2,

              todayTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 16.0, // 기본 크기 유지
                fontWeight: FontWeight.normal,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 16.0, // 크기 증가 없음
                fontWeight: FontWeight.normal,
              ),
              defaultTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            daysOfWeekHeight: 36.0,
            rowHeight: 52.0,

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.black),
              weekendStyle: TextStyle(color: Colors.black),
            ),
            calendarBuilders: CalendarBuilders(
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  height: 52, // 셀 높이 고정
                  child: Stack(
                    children: [
                      // 배경 원
                      Positioned(
                        top: 5, // 동그라미를 위로 올림
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade100,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // 숫자 텍스트 (배경 원 위에)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },

              selectedBuilder: (context, day, selectedDay) {
                return Container(
                  height: 52, // 셀 높이 고정
                  child: Stack(
                    children: [
                      // 배경 원
                      Positioned(
                        top: 5, // 동그라미를 위로 올림
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // 숫자 텍스트 (배경 원 위에)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },

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
                return Container(
                  height: 52, // 셀 높이 고정
                  child: Stack(
                    children: [
                      // 숫자 텍스트 (상단에 고정)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },

              markerBuilder: (context, date, events) {
                try {
                  if (events.isEmpty) return null;

                  final validEvents = events
                      .where((event) => event != null)
                      .cast<Event>()
                      .toList();

                  if (validEvents.isEmpty) return null;

                  // 이벤트를 4개씩 그룹으로 나누기
                  List<List<Event>> eventRows = [];
                  for (int i = 0; i < validEvents.length; i += 4) {
                    int endIndex = (i + 4 > validEvents.length) ? validEvents.length : i + 4;
                    eventRows.add(validEvents.sublist(i, endIndex));
                  }

                  return Positioned(
                    top: 36.5, // 숫자 아래 고정된 위치에서 시작 (간격 늘림)
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: eventRows.map<Widget>((row) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 1.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: row.map<Widget>((event) {
                                return Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: getRandomColor(
                                        event.isLongTerm != '' ? event.isLongTerm : event.id
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                } catch (e) {
                  print('MarkerBuilder 오류: $e');
                  // 오류 발생 시 기본 마커 표시
                  return Positioned(
                    top: 35,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple.shade200,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ]
    );
  }

  Color getRandomColor(String seed) {
    final hash = seed.hashCode;
    final random = Random(hash);
    return Color.fromARGB(
      255,
      100 + random.nextInt(156), // R: 100~255
      100 + random.nextInt(156), // G: 100~255
      100 + random.nextInt(156), // B: 100~255
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
              child: Container(
                width: double.infinity,
                child: EventCard(
                  event: event,
                  onEdit: () => _showEventDetailsDialog(event),
                  onDelete: _deleteEvent,
                  onMorePressed: () => _showEventDetailsDialog(event),
                ),
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

  // 장기 일정 전체 삭제
  Future<void> _deleteLongTermEvent(Event event) async {
    try {
      print('=== 삭제 시작 ===');
      print('이벤트 ID: ${event.id}');
      print('isLongTerm: ${event.isLongTerm}');

      final originalId = event.isLongTerm;
      final batch = FirebaseFirestore.instance.batch();

      print('원본 문서 삭제 준비...');
      final originalEventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(originalId);
      batch.delete(originalEventRef);

      print('관련 문서들 검색 중...');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('isLongTerm', isEqualTo: originalId)
          .get();

      print('찾은 관련 문서 수: ${querySnapshot.docs.length}');

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      print('배치 커밋 시작...');
      await batch.commit();
      print('배치 커밋 완료!');

      // UI 업데이트
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장기 일정이 모두 삭제되었습니다.')),
        );
      }
    } catch (e) {
      print('=== 삭제 오류 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 내용: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _deleteEvent(Event event, String deleteType) async {
    try {
      if (event.isLongTerm != '') {
        await _deleteLongTermEvent(event);
      } else {
        await _deleteThis(event);
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

  // 단일 일정 삭제(반복 일정이 아닌 경우)
  Future<void> _deleteThis(Event event) async {
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

class ExpandingFAB extends StatefulWidget {
  final VoidCallback onSchedulePressed;
  final VoidCallback onTodoPressed;

  const ExpandingFAB({
    Key? key,
    required this.onSchedulePressed,
    required this.onTodoPressed,
  }) : super(key: key);

  @override
  State<ExpandingFAB> createState() => _ExpandingFABState();
}

class _ExpandingFABState extends State<ExpandingFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  bool isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300) // 애니메이션 속도 조정
    );
    _expandAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut // 확장 애니메이션 곡선
    );

    // 회전 애니메이션 추가 (45도 회전)
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45도 = π/4 = 0.125 * 2π
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // 회전 애니메이션 곡선
    ));
  }

  void _toggle() {
    setState(() {
      isOpen = !isOpen;
    });

    if (isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end, // 오른쪽 정렬로 시작
      children: [
        // 투두리스트 버튼
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Container(
              height: 60 * _expandAnimation.value, // 버튼 간격 조정
              child: _expandAnimation.value > 0.1
                  ? Padding(
                padding: EdgeInsets.only(bottom: 8), // 버튼 간격 조정
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 라벨
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, // 라벨 가로 패딩
                          vertical: 6 // 라벨 세로 패딩
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6), // 라벨 배경색 투명도
                        borderRadius: BorderRadius.circular(20), // 라벨 모서리 둥글기
                      ),
                      child: Text(
                        '투두리스트 추가',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12, // 라벨 글자 크기
                        ),
                      ),
                    ),
                    SizedBox(width: 10), // 라벨과 버튼 사이 간격
                    // 버튼 - 메인 FAB와 같은 위치에 오도록 조정
                    FloatingActionButton(
                      heroTag: "todo",
                      mini: false, // 일반 크기로 변경
                      backgroundColor: Color(0xFFFFFFFF).withOpacity(0.8), // 버튼 배경색
                      onPressed: () {
                        print('투두리스트 버튼 눌림!');
                        widget.onTodoPressed();
                        _toggle();
                      },
                      child: Icon(
                        Icons.checklist_rtl,
                        color: Color(0xFF9F97DA).withOpacity(0.8),
                        size: 28, // 아이콘 크기 조정
                      ),
                    ),
                  ],
                ),
              )
                  : SizedBox.shrink(),
            );
          },
        ),

        // 일정 버튼
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Container(
              height: 60 * _expandAnimation.value, // 버튼 간격 조정
              child: _expandAnimation.value > 0.1
                  ? Padding(
                padding: EdgeInsets.only(bottom: 8), // 버튼 간격 조정
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 라벨
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, // 라벨 가로 패딩
                          vertical: 6 // 라벨 세로 패딩
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6), // 라벨 배경색 투명도
                        borderRadius: BorderRadius.circular(20), // 라벨 모서리 둥글기
                      ),
                      child: Text(
                        '일정 추가',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12, // 라벨 글자 크기
                        ),
                      ),
                    ),
                    SizedBox(width: 10), // 라벨과 버튼 사이 간격
                    // 버튼 - 메인 FAB와 같은 위치에 오도록 조정
                    FloatingActionButton(
                      heroTag: "schedule",
                      mini: false, // 일반 크기로 변경
                      backgroundColor: Color(0xFFFFFFFF).withOpacity(0.8), // 버튼 배경색
                      onPressed: () {
                        print('일정 버튼 눌림!');
                        widget.onSchedulePressed();
                        _toggle();
                      },
                      child: Icon(
                        Icons.calendar_today,
                        color: Color(0xFF9F97DA).withOpacity(0.8),
                        size: 28, // 아이콘 크기 조정
                      ),
                    ),
                  ],
                ),
              )
                  : SizedBox.shrink(),
            );
          },
        ),

        // 메인 FAB
        FloatingActionButton(
          backgroundColor: isOpen ? Color(0xFFDF4848).withOpacity(0.8): Color(
              0xFFB39DDB).withOpacity(0.8), // 메인 버튼 배경색
          onPressed: () {
            print('메인 버튼 눌림! isOpen: $isOpen');
            _toggle();
          },
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159, // 회전 각도 계산
                child: Icon(
                  Icons.add, // 항상 + 아이콘으로 고정
                  color: Colors.white.withOpacity(0.8),
                  size: 28, // 메인 버튼 아이콘 크기 (다른 버튼과 통일)
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}