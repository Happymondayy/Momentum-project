import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:momentum_planner/AI/chat_service.dart';
import 'package:momentum_planner/AI/ai_advice_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Calendar/models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../Planner/DailyPlannerPage.dart';

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> calendarData;
  final List<Map<String, dynamic>> todoData;
  final String userId;
  final Function(Map<String, dynamic>) onEventAdded;
  final Function(String) onEventDeleted;

  const ChatScreen({
    Key? key,
    required this.calendarData,
    required this.todoData,
    required this.userId,
    required this.onEventAdded,
    required this.onEventDeleted,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _quickOptions = [];
  bool _isLoading = false;
  bool _isOfflineMode = false;
  late ChatService _chatService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  late String userId;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    print('📌 userId 받은 값: $userId');

    // 대화 기록 먼저 로드
    _loadMessages().then((_) {
      // 대화 기록이 비어있는 경우에만 초기화 메시지 추가
      if (_messages.isEmpty) {
        _initializeChatService();
      } else {
        // 기존 대화가 있으면 채팅 서비스만 초기화
        _chatService = ChatService(userId: widget.userId);
        setState(() {
          _isOfflineMode = false;
          _isLoading = false;
        });

        // 빠른 옵션(말풍선) 생성
        _quickOptions = AIAdviceService.generateRecommendationOptions(
            widget.calendarData,
            widget.todoData
        );
      }
    });
  }

  // 메시지 저장 함수
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 대화 내용을 JSON 문자열로 변환하여 저장
      await prefs.setString('chat_history_${widget.userId}', jsonEncode(_messages));
    } catch (e) {
      print('대화 저장 오류: $e');
    }
  }

  // 메시지 로드 함수
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getString('chat_history_${widget.userId}');

      if (history != null && history.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(history);
        setState(() {
          _messages = List<Map<String, dynamic>>.from(
              decoded.map((item) => Map<String, dynamic>.from(item))
          );
        });
      }
    } catch (e) {
      print('대화 로드 오류: $e');
    }
  }

  Future<void> _initializeChatService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _chatService = ChatService(userId: widget.userId);

      // 간단한 테스트 메시지로 서비스 연결 상태 확인
      final testResponse = await _chatService.generateOfflineResponse("테스트");

      // 빠른 옵션(말풍선) 생성
      _quickOptions = AIAdviceService.generateRecommendationOptions(
          widget.calendarData,
          widget.todoData
      );

      setState(() {
        _isOfflineMode = false;
        _isLoading = false;
      });

      // 사용자 닉네임 가져와서 인사말에 포함
      String nickname = '사용자'; // 기본값
      try {
        nickname = await AIAdviceService.getUserNickname();
      } catch (e) {
        print('닉네임 로드 오류: $e');
      }

      // 오늘 일정 요약
      String briefingMessage = await _generateDailyBriefing(nickname);
      _addSystemMessage(briefingMessage);
    } catch (e) {
      print('초기화 오류: $e');

      // 오류 발생 시 오프라인 모드 활성화
      _chatService = ChatService(userId: widget.userId);

      // 오프라인 모드에서도 기본 옵션 제공
      _quickOptions = [
        {
          "text": "오늘의 추천 일정",
          "action": "suggest_schedule",
          "icon": "calendar"
        },
        {
          "text": "빈 시간 활용하기",
          "action": "free_time",
          "icon": "time"
        },
        {
          "text": "시간 관리 팁",
          "action": "time_tips",
          "icon": "bulb"
        }
      ];

      setState(() {
        _isOfflineMode = true;
        _isLoading = false;
      });

      _addSystemMessage("안녕하세요! 현재 오프라인 모드로 작동 중입니다. 제한된 기능만 사용 가능합니다.");
    }
  }

  Future<String> _generateDailyBriefing(String nickname) async {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // 오늘 할 일 목록 가져오기
    final todayTasks = widget.todoData.where((task) {
      return task['date'] == today || (task['date'] != null && task['date'].startsWith(today));
    }).toList();

    // 미완료 할 일 개수 계산
    final incompleteTasks = todayTasks.where((task) => task['isCompleted'] != true).length;

    // 브리핑 메시지 생성 - 투두리스트만 포함
    String message = "안녕하세요, ${nickname}님! 🌟\n\n";

    // 요일 구하기
    final weekdays = ["월", "화", "수", "목", "금", "토", "일"];
    final weekday = weekdays[now.weekday - 1];

    // 계절감 있는 인사 추가
    List<String> seasonalGreetings = [
      "오늘도 활기찬 하루 되세요!",
      "오늘 하루도 파이팅하세요!",
      "오늘도 좋은 일이 있기를 바라요.",
      "함께 오늘 하루를 계획해볼까요?"
    ];
    final greeting = seasonalGreetings[now.millisecond % seasonalGreetings.length];

    message += "오늘은 ${now.year}년 ${now.month}월 ${now.day}일 $weekday요일이에요. $greeting\n\n";

    // 할 일 요약
    if (todayTasks.isNotEmpty) {
      final completedTasks = todayTasks.length - incompleteTasks;
      final percentComplete = todayTasks.isEmpty ? 0 : (completedTasks / todayTasks.length * 100).round();

      message += "📝 오늘의 할 일 ($completedTasks/${todayTasks.length}개 완료, $percentComplete%):\n";

      // 완료되지 않은 일부터 표시
      final notCompletedTasks = todayTasks.where((task) => task['isCompleted'] != true).toList();
      for (int i = 0; i < min(3, notCompletedTasks.length); i++) {
        final task = notCompletedTasks[i];
        message += "• ${task['title']}\n";
      }

      if (notCompletedTasks.length > 3) {
        message += "  그 외 ${notCompletedTasks.length - 3}개의 할 일이 더 있어요.\n";
      }

      message += "\n";

      // 응원 메시지 추가
      if (percentComplete >= 70) {
        message += "대단해요! 오늘 할 일의 대부분을 이미 완료하셨네요. 😄\n\n";
      } else if (percentComplete >= 30) {
        message += "순조롭게 진행 중이네요! 앞으로도 화이팅! 👍\n\n";
      } else if (todayTasks.isNotEmpty) {
        message += "오늘 할 일을 차근차근 시작해볼까요? 저도 도울게요! 💪\n\n";
      }
    } else {
      message += "📝 오늘은 등록된 할 일이 없어요. 새로운 목표를 설정해볼까요?\n\n";
    }

    message += "무엇을 도와드릴까요? 😊";

    return message;
  }

  // 추천 일정 대화상자 표시 함수
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
                  '추천 일정 생성 중...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '현재 일정과 할 일을 분석하여\n최적의 추천 일정을 생성하고 있습니다.',
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

    // AI 일정 생성 수행
    _generateAIScheduleRecommendation();
  }

  // AI 일정 추천 생성 함수
  Future<void> _generateAIScheduleRecommendation() async {
    try {
      // 현재 시간 가져오기
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 오늘 일정 가져오기
      final todayCalendarEvents = widget.calendarData.where((event) =>
      event['date'] == formattedDate || (event['date'] != null && event['date'].startsWith(formattedDate))
      ).toList();

      // 오늘 할 일 가져오기
      final todayTodoTasks = widget.todoData.where((task) =>
      task['date'] == formattedDate || (task['date'] != null && task['date'].startsWith(formattedDate))
      ).toList();

      // 서버에 일정 추천 요청 준비
      final response = await _chatService.chatWithAssistant(
        message: "오늘 내 시간을 효율적으로 사용할 수 있는 최적의 일정을 추천해주세요. 빈 시간에 할만한 활동과 함께 시간표를 짜주세요.",
        calendar: todayCalendarEvents,
        tasks: todayTodoTasks,
        history: [],
        action: "recommend_schedule",
      );

      // 다이얼로그 닫기
      Navigator.pop(context);

      // 추천 결과 표시
      if (response.containsKey('response')) {
        _addSystemMessage(response['response']);

        // 액션이 있으면 처리
        if (response.containsKey('actions') && response['actions'] is List && response['actions'].isNotEmpty) {
          final actions = response['actions'] as List;
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': '추천된 일정을 적용하시겠습니까?',
              'actions': actions,
            });
          });
          _saveMessages(); // 추가된 메시지 저장
        }
      } else {
        _addSystemMessage("죄송합니다. 추천 일정을 생성하는 중 오류가 발생했습니다.");
      }
    } catch (e) {
      print('추천 일정 생성 오류: $e');

      // 다이얼로그가 열려있으면 닫기
      Navigator.of(context, rootNavigator: true).pop();

      _addSystemMessage("추천 일정을 생성하는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
    }
  }

  // Todo 항목 추가 함수
  Future<void> _addTodo(Map<String, dynamic> todoData) async {
    try {
      // 필수 필드 확인
      if (todoData['title'] == null || todoData['title'].toString().isEmpty) {
        _addSystemMessage("할 일 추가에 실패했습니다. 제목이 필요합니다.");
        return;
      }

      // 날짜 처리
      String dateStr = todoData['date'] ?? DateTime.now().toString().split(' ')[0];
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        // 날짜 형식이 잘못된 경우 오늘 날짜 사용
        date = DateTime.now();
      }

      // todo 문서 데이터 준비
      final data = {
        'userId': widget.userId,
        'title': todoData['title'],
        'date': date.toIso8601String(),
        'time': todoData['time'] ?? '',
        'endTime': todoData['endTime'] ?? '',
        'importance': todoData['importance'] ?? 1,
        'urgency': todoData['urgency'] ?? 1,
        'isCompleted': false,
        'memo': todoData['memo'] ?? '',
        'location': todoData['location'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Firestore에 저장
      await FirebaseFirestore.instance.collection('todos').add(data);

      // 부모에게 알림 (UI 업데이트)
      setState(() {
        widget.todoData.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': todoData['title'],
          'date': dateStr,
          'time': todoData['time'] ?? '',
          'endTime': todoData['endTime'] ?? '',
          'importance': todoData['importance'] ?? 1,
          'urgency': todoData['urgency'] ?? 1,
          'isCompleted': false,
          'memo': todoData['memo'] ?? '',
          'location': todoData['location'] ?? '',
        });
      });

      _addSystemMessage("'${todoData['title']}' 할 일이 추가되었습니다.");
    } catch (e) {
      print('할 일 추가 오류: $e');
      _addSystemMessage("할 일 추가 중 오류가 발생했습니다: $e");
    }
  }

  // Todo 항목 삭제 함수
  Future<void> _deleteTodo(Map<String, dynamic> todoData) async {
    try {
      String? todoId;
      String title = todoData['title'] ?? '';

      // ID로 삭제
      if (todoData['id'] != null) {
        todoId = todoData['id'].toString();
      }
      // 제목으로 찾아서 삭제
      else if (title.isNotEmpty) {
        // 원본 todoData에서 제목으로 검색
        for (var todo in widget.todoData) {
          if (todo['title'] == title) {
            todoId = todo['id'].toString();
            break;
          }
        }
      }

      if (todoId == null || todoId.isEmpty) {
        _addSystemMessage("삭제할 할 일을 찾을 수 없습니다.");
        return;
      }

      // Firestore에서 삭제
      final querySnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: widget.userId)
          .where('title', isEqualTo: title)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      // 로컬 데이터 업데이트
      setState(() {
        widget.todoData.removeWhere((todo) =>
        todo['id'] == todoId || todo['title'] == title
        );
      });

      _addSystemMessage("'$title' 할 일이 삭제되었습니다.");
    } catch (e) {
      print('할 일 삭제 오류: $e');
      _addSystemMessage("할 일 삭제 중 오류가 발생했습니다: $e");
    }
  }

  void _addSystemMessage(String message) {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': message,
      });
    });

    _saveMessages(); // 변경 내용 저장
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
      });
    });

    _saveMessages(); // 변경 내용 저장
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text;
    _addUserMessage(message);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> response;

      if (_isOfflineMode) {
        // 오프라인 모드일 경우 기본 응답 생성
        response = _chatService.generateOfflineResponse(message);
      } else {
        // 온라인 모드 - 타임아웃 설정
        response = await _chatService.chatWithAssistant(
          message: message,
          calendar: widget.calendarData,
          tasks: widget.todoData,
          history: _messages,
        ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              // 타임아웃 발생 시 오프라인 모드로 전환
              setState(() {
                _isOfflineMode = true;
              });
              return _chatService.generateOfflineResponse(message);
            }
        );
      }

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response['response'],
          'actions': response['actions'] ?? [],
        });
        _isLoading = false;

        // 새로운 추천 옵션 업데이트
        if (response['options'] != null) {
          _quickOptions = List<Map<String, dynamic>>.from(response['options']);
        }
      });

      _saveMessages(); // 변경 내용 저장
      _scrollToBottom();

      // 액션 처리
      if (response['actions'] != null && (response['actions'] as List).isNotEmpty) {
        _processActions(response['actions']);
      }

    } catch (e) {
      print('메시지 전송 오류: $e');

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '죄송합니다. 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        });
        _isLoading = false;
        _isOfflineMode = true; // 오류 발생 시 오프라인 모드로 전환
      });

      _saveMessages(); // 변경 내용 저장
      _scrollToBottom();
    }
  }

  // 빠른 옵션 클릭 처리 함수 추가
  void _handleQuickOptionTap(Map<String, dynamic> option) async {
    final action = option['action'];

    if (action != null) {
      _addUserMessage(option['text']);

      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic> response;

        if (_isOfflineMode) {
          response = _chatService.generateOfflineResponse(option['text']);
        } else {
          response = await _chatService.chatWithAssistant(
            message: option['text'],
            calendar: widget.calendarData,
            tasks: widget.todoData,
            history: _messages,
            action: action,
          ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                setState(() {
                  _isOfflineMode = true;
                });
                return _chatService.generateOfflineResponse(option['text']);
              }
          );
        }

        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': response['response'],
            'actions': response['actions'] ?? [],
          });

          _isLoading = false;

          // 새로운 추천 옵션 업데이트
          if (response['options'] != null) {
            _quickOptions = List<Map<String, dynamic>>.from(response['options']);
          }
        });

        _saveMessages(); // 변경 내용 저장
        _scrollToBottom();

        if (response['actions'] != null && (response['actions'] as List).isNotEmpty) {
          _processActions(response['actions']);
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _messages.add({
            'role': 'assistant',
            'content': '죄송합니다. 요청을 처리하는 중 오류가 발생했습니다.',
          });
        });
        _saveMessages(); // 변경 내용 저장
        print('빠른 옵션 처리 오류: $e');
      }
    }
  }

  // _addEvent 함수 수정
  Future<void> _addEvent(Map<String, dynamic> eventData) async {
    try {
      // 필수 데이터 확인
      if (eventData['title'] == null || eventData['title'].toString().isEmpty) {
        _addSystemMessage("일정 추가에 실패했습니다. 제목이 없습니다.");
        return;
      }

      // 날짜 및 시간 처리
      String date = eventData['date'] ?? DateTime.now().toString().split(' ')[0];
      String? startTimeStr = eventData['time'];
      String? endTimeStr = eventData['endTime'];

      // 시간 문자열을 TimeOfDay로 변환
      TimeOfDay? startTime;
      TimeOfDay? endTime;

      if (startTimeStr != null && startTimeStr.isNotEmpty) {
        final timeParts = startTimeStr.split(':');
        if (timeParts.length >= 2) {
          startTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1].split(' ')[0]),
          );
        }
      }

      if (endTimeStr != null && endTimeStr.isNotEmpty) {
        final timeParts = endTimeStr.split(':');
        if (timeParts.length >= 2) {
          endTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1].split(' ')[0]),
          );
        }
      } else if (startTime != null && eventData['duration'] != null) {
        // 시작 시간 + 지속 시간으로 종료 시간 계산
        final durationParts = eventData['duration'].toString().split(':');
        if (durationParts.length >= 2) {
          final durationHours = int.parse(durationParts[0]);
          final durationMinutes = int.parse(durationParts[1]);

          final totalMinutes = startTime.hour * 60 + startTime.minute + durationHours * 60 + durationMinutes;
          endTime = TimeOfDay(
            hour: (totalMinutes ~/ 60) % 24,
            minute: totalMinutes % 60,
          );
        }
      }

      // DateTime 객체 생성
      final dateComponents = date.split('-');
      if (dateComponents.length < 3) {
        _addSystemMessage("일정 추가에 실패했습니다. 날짜 형식이 올바르지 않습니다.");
        return;
      }

      final eventDate = DateTime(
        int.parse(dateComponents[0]),
        int.parse(dateComponents[1]),
        int.parse(dateComponents[2]),
      );

      // 이벤트 ID 생성
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();

      // Firestore에 저장할 데이터 준비
      final eventDocData = {
        'id': eventId,
        'userId': userId,
        'title': eventData['title'],
        'date': Timestamp.fromDate(eventDate),
        'startDate': Timestamp.fromDate(eventDate), // 캘린더 이벤트용
        'endDate': Timestamp.fromDate(eventDate), // 캘린더 이벤트용
        'startTime': startTime != null ? {
          'hour': startTime.hour,
          'minute': startTime.minute,
        } : null,
        'endTime': endTime != null ? {
          'hour': endTime.hour,
          'minute': endTime.minute,
        } : null,
        'location': eventData['location'] ?? '',
        'description': eventData['description'] ?? eventData['memo'] ?? '',
        'memo': eventData['memo'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'color': eventData['color'] ?? '#9D8CFF', // 기본 색상
        'isCompleted': false,
        'isAllDay': eventData['isAllDay'] ?? false,
        'importance': eventData['importance'] ?? 3,
        'urgency': eventData['urgency'] ?? 3,
      };

      // 일정 타입에 따라 다른 컬렉션에 저장
      if (eventData['type'] == 'todo') {
        // Todo 컬렉션에 저장
        await _firestore.collection('todos').doc(eventId).set(eventDocData);

        // 로컬 데이터 업데이트 (투두리스트에 즉시 반영)
        final todo = {
          'id': eventId,
          'title': eventData['title'],
          'date': eventDate.toString().split(' ')[0],
          'time': startTimeStr,
          'endTime': endTimeStr,
          'memo': eventData['memo'] ?? '',
          'location': eventData['location'] ?? '',
          'importance': eventData['importance'] ?? 3,
          'urgency': eventData['urgency'] ?? 3,
          'isCompleted': false,
        };

        setState(() {
          widget.todoData.add(todo);
        });

        _addSystemMessage("'${eventData['title']}' 할 일이 추가되었습니다.");
      } else {
        // Events 컬렉션에 저장 (캘린더용)
        await _firestore.collection('events').doc(eventId).set(eventDocData);

        // 로컬 데이터 업데이트 (캘린더에 즉시 반영)
        final event = {
          'id': eventId,
          'title': eventData['title'],
          'date': eventDate.toString().split(' ')[0],
          'startDate': eventDate.toString().split(' ')[0],
          'endDate': eventDate.toString().split(' ')[0],
          'startTime': startTime != null ? {
            'hour': startTime.hour,
            'minute': startTime.minute,
          } : null,
          'endTime': endTime != null ? {
            'hour': endTime.hour,
            'minute': endTime.minute,
          } : null,
          'description': eventData['description'] ?? eventData['memo'] ?? '',
          'memo': eventData['memo'] ?? '',
          'location': eventData['location'] ?? '',
          'isAllDay': eventData['isAllDay'] ?? false,
        };

        // 부모 위젯에 정보 전달해 UI 업데이트
        widget.onEventAdded(event);

        // 캘린더 데이터에도 직접 추가
        setState(() {
          widget.calendarData.add(event);
        });

        print('캘린더 일정 추가됨: ${event['title']} [${event['date']}]');
        _addSystemMessage("'${eventData['title']}' 일정이 캘린더에 추가되었습니다.");
      }
    } catch (e) {
      print('일정 추가 오류: $e');
      _addSystemMessage("일정 추가 중 오류가 발생했습니다: $e");
    }
  }

// 액션 처리 함수
  void _processActions(List<dynamic> actions) {
    try {
      // 여기서 각 액션 유형에 따라 처리
      for (var action in actions) {
        if (action is Map<String, dynamic>) {
          final actionType = action['action'];
          final actionData = action['data'];

          switch (actionType) {
            case 'add_task':
            // 일정 추가 로직
              print('일정 추가 액션: $actionData');

              // TodoList 항목이면 type을 todo로 설정
              if (actionData != null && actionData is Map<String, dynamic>) {
                // 텍스트에 (할일) 또는 (todo)가 들어있으면 todo 타입으로 처리
                final title = actionData['title'] ?? '';
                if (title.toLowerCase().contains('할일') ||
                    title.toLowerCase().contains('할 일') ||
                    title.toLowerCase().contains('todo') ||
                    (actionData['importance'] != null && actionData['urgency'] != null)) {
                  actionData['type'] = 'todo';
                } else {
                  actionData['type'] = 'event';
                }
              }

              _addEvent(actionData);
              break;

            case 'delete_task':
            // 일정 삭제 로직
              print('일정 삭제 액션: $actionData');
              _deleteEvent(actionData);
              break;

            case 'recommend_task':
            // 일정 추천 로직
              print('일정 추천 액션: $actionData');

              // 추천 확인 대화상자 표시
              _showRecommendationDialog(actionData);
              break;

            case 'view_calendar':
            // 캘린더 보기 로직
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('캘린더 화면으로 이동합니다...')),
              );

              // 메인 캘린더 화면으로 이동
              Future.delayed(Duration(seconds: 1), () {
                Navigator.pushReplacementNamed(
                  context,
                  'Calendar/screens/calendar_screen',
                  arguments: {'userId': widget.userId},
                );
              });
              break;

            case 'view_tasks':
            // 할 일 목록 보기 로직
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('플래너 화면으로 이동합니다...')),
              );

              // 플래너 화면으로 이동
              Future.delayed(Duration(seconds: 1), () {
                Navigator.pushReplacementNamed(
                  context,
                  'Planner/DailyPlannerPage',
                  arguments: {'userId': widget.userId},
                );
              });
              break;

            default:
              print('정의되지 않은 액션 타입: $actionType');
              break;
          }
        }
      }
    } catch (e) {
      print('액션 처리 오류: $e');
      // 오류가 있어도 채팅은 계속 진행
    }
  }

// 일정 삭제 함수
  Future<void> _deleteEvent(Map<String, dynamic> eventData) async {
    try {
      String? eventId;
      String title = eventData['title'] ?? '';

      // ID로 삭제
      if (eventData['id'] != null) {
        eventId = eventData['id'].toString();
      }
      // 제목으로 찾아서 삭제
      else if (title.isNotEmpty) {
        // 원본 캘린더 데이터에서 제목으로 검색
        for (var event in widget.calendarData) {
          if (event['title'] == title) {
            eventId = event['id'].toString();
            break;
          }
        }
      }

      if (eventId == null || eventId.isEmpty) {
        _addSystemMessage("삭제할 일정을 찾을 수 없습니다.");
        return;
      }

      // Firestore에서 삭제
      await _firestore.collection('events').doc(eventId).delete();

      // 부모에게 삭제 알림
      widget.onEventDeleted(eventId);

      // 성공 메시지
      _addSystemMessage("'$title' 일정이 삭제되었습니다.");
    } catch (e) {
      print('일정 삭제 오류: $e');
      _addSystemMessage("일정 삭제 중 오류가 발생했습니다: $e");
    }
  }

// 추천 확인 대화상자
  void _showRecommendationDialog(Map<String, dynamic> recommendation) {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('일정 추천'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('제목: ${recommendation['title'] ?? '제목 없음'}'),
              const SizedBox(height: 8),
              if (recommendation['description'] != null)
                Text('설명: ${recommendation['description']}'),
              const SizedBox(height: 8),
              if (recommendation['time'] != null)
                Text('시간: ${recommendation['time']}${recommendation['endTime'] != null ? ' ~ ${recommendation['endTime']}' : ''}'),
              const SizedBox(height: 16),
              const Text('이 일정을 추가하시겠습니까?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                // 추천 일정 추가
                _addEvent(recommendation);
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('추천 대화상자 표시 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 챗봇'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DailyPlannerPage(
                  userId: widget.userId,
                  calendarData: widget.calendarData,
                ),
              ),
            );
          },
        ),
        actions: [
          // 대화 초기화 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetConversation,
            tooltip: '대화 초기화',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 오늘 일정 요약 카드
          _buildDailyScheduleCard(),

          // 오프라인 모드 알림 배너
          if (_isOfflineMode)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '오프라인 모드로 작동 중입니다. 제한된 기능만 사용 가능합니다.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 채팅 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';

                // 각 메시지 챗 버블 생성
                return _buildChatBubble(message, isUser);
              },
            ),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            _buildLoadingIndicator(),

          // 빠른 옵션 말풍선 UI
          if (_quickOptions.isNotEmpty)
            _buildQuickOptions(),

          // 입력 영역
          _buildMessageInput(),
        ],
      ),
    );
  }

// 대화 초기화 함수 추가
  void _resetConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('대화 초기화'),
        content: Text('대화 내용을 모두 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _messages = [];
                _isLoading = true;
              });
              await _saveMessages(); // 빈 메시지 목록 저장

              // 새로운 대화 시작
              try {
                _chatService = ChatService(userId: widget.userId);

                // 빠른 옵션 재생성
                _quickOptions = AIAdviceService.generateRecommendationOptions(
                    widget.calendarData,
                    widget.todoData
                );

                setState(() {
                  _isOfflineMode = false;
                });

                // 사용자 닉네임 가져와서 인사말에 포함
                String nickname = '사용자'; // 기본값
                try {
                  nickname = await AIAdviceService.getUserNickname();
                } catch (e) {
                  print('닉네임 로드 오류: $e');
                }

                // 오늘 일정 요약
                String briefingMessage = await _generateDailyBriefing(nickname);

                setState(() {
                  _isLoading = false;
                  _messages.add({
                    'role': 'assistant',
                    'content': briefingMessage,
                  });
                });

                _saveMessages(); // 변경 내용 저장
                _scrollToBottom();

              } catch (e) {
                print('초기화 오류: $e');

                setState(() {
                  _isLoading = false;
                  _isOfflineMode = true; // 오류 발생 시 오프라인 모드로 전환
                  _messages.add({
                    'role': 'assistant',
                    'content': "안녕하세요! 현재 오프라인 모드로 작동 중입니다. 제한된 기능만 사용 가능합니다.",
                  });
                });

                _saveMessages(); // 변경 내용 저장
              }
            },
            child: Text('초기화'),
          ),
        ],
      ),
    );
  }

  // 대화 내용 기반으로 일정 추가를 위한 수정된 _buildDailyScheduleCard 함수
  Widget _buildDailyScheduleCard() {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 캘린더 일정만 가져오기 (투두리스트 제외)
    final todayEvents = widget.calendarData.where((event) {
      return event['date'] == today || (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    // 일정이 없으면 표시 안함
    if (todayEvents.isEmpty) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFAFAFA), // 거의 흰색에 가까운 아주 연한 회색
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFEEEEEE), width: 1), // 연한 경계선 추가
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks', // "MY DAY"에서 "Tasks"로 변경
            style: TextStyle(
              fontSize: 16, // 폰트 크기 줄임: 20 -> 16
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),

          // 캘린더 일정만 표시 (투두리스트 제외)
          ...todayEvents.take(5).map((event) { // 최대 5개까지 표시하도록 증가
            String timeInfo = '';
            if (event['startTime'] != null) {
              if (event['startTime'] is Map) {
                final hour = event['startTime']['hour'] ?? 0;
                final minute = event['startTime']['minute'] ?? 0;
                timeInfo = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
              } else if (event['startTime'] is String) {
                timeInfo = event['startTime'].toString();
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300, // 연한 파란색
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event['title'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (timeInfo.isNotEmpty)
                    Text(
                      timeInfo,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),

          // 더 많은 일정이 있는 경우 표시
          if (todayEvents.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '+ ${todayEvents.length - 5} more tasks',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

// 챗봇에서 일정 추가 흐름을 처리하는 기능
  Future<void> _handleScheduleRequest(String message) async {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('일정') && (lowerMessage.contains('추가') || lowerMessage.contains('만들어') || lowerMessage.contains('저장'))) {
      _addUserMessage(message);

      // 추가 단계: 캘린더 또는 투두리스트 선택 질문
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '어디에 일정을 추가할까요? 캘린더에 추가할까요, 아니면 투두리스트에 추가할까요?',
          'expectingChoice': true,
          'choices': ['캘린더', '투두리스트'],
        });
      });

      _saveMessages(); // 변경 내용 저장
      _scrollToBottom();
    }
  }

// 사용자 선택에 따른 일정 유형 처리
  Map<String, dynamic> _schedulingState = {
    'isScheduling': false,
    'type': null, // 'calendar' or 'todo'
    'step': 0, // 0: 시작, 1: 제목, 2: 날짜, 3: 시간
    'data': {}, // 수집된 일정 데이터
  };

  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text;
    _addUserMessage(message);
    _messageController.clear();

    // 일정 추가 중인지 확인
    if (_schedulingState['isScheduling']) {
      await _processSchedulingStep(message);
      return;
    }

    // 일정 추가를 시작하는 경우
    if (message.toLowerCase().contains('일정') &&
        (message.toLowerCase().contains('추가') ||
            message.toLowerCase().contains('만들어') ||
            message.toLowerCase().contains('저장'))) {

      setState(() {
        _schedulingState = {
          'isScheduling': true,
          'step': 1, // 일정 유형 선택 단계로 시작
          'data': {},
        };

        _messages.add({
          'role': 'assistant',
          'content': '어디에 일정을 추가할까요? 캘린더에 추가할까요, 아니면 투두리스트에 추가할까요?',
        });
      });

      _saveMessages();
      _scrollToBottom();
      return;
    }

    // 일반적인 메시지 처리
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> response;

      if (_isOfflineMode) {
        // 오프라인 모드일 경우 기본 응답 생성
        response = _chatService.generateOfflineResponse(message);
      } else {
        // 온라인 모드 - 타임아웃 설정
        response = await _chatService.chatWithAssistant(
          message: message,
          calendar: widget.calendarData,
          tasks: widget.todoData,
          history: _messages,
        ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              // 타임아웃 발생 시 오프라인 모드로 전환
              setState(() {
                _isOfflineMode = true;
              });
              return _chatService.generateOfflineResponse(message);
            }
        );
      }

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response['response'],
          'actions': response['actions'] ?? [],
        });
        _isLoading = false;

        // 새로운 추천 옵션 업데이트
        if (response['options'] != null) {
          _quickOptions = List<Map<String, dynamic>>.from(response['options']);
        }
      });

      _saveMessages(); // 변경 내용 저장
      _scrollToBottom();

      // 액션 처리
      if (response['actions'] != null && (response['actions'] as List).isNotEmpty) {
        _processActions(response['actions']);
      }

    } catch (e) {
      print('메시지 전송 오류: $e');

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '죄송합니다. 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        });
        _isLoading = false;
        _isOfflineMode = true; // 오류 발생 시 오프라인 모드로 전환
      });

      _saveMessages(); // 변경 내용 저장
      _scrollToBottom();
    }
  }

// 일정 추가 단계별 처리 함수
  Future<void> _processSchedulingStep(String message) async {
    _addUserMessage(message);

    final step = _schedulingState['step'];

    // 단계 1: 일정 유형 선택 (캘린더 또는 투두리스트)
    if (step == 1) {
      String type = '';

      if (message.contains('캘린더') || message.contains('일정')) {
        type = 'calendar';
        _schedulingState['type'] = 'calendar';
      } else if (message.contains('투두') || message.contains('할 일') || message.contains('todo')) {
        type = 'todo';
        _schedulingState['type'] = 'todo';
      } else {
        // 유형을 인식할 수 없는 경우
        _addSystemMessage('캘린더 또는 투두리스트 중 어디에 추가할지 알려주세요.');
        return;
      }

      _schedulingState['step'] = 2;
      _addSystemMessage('일정의 제목을 알려주세요.');
    }

    // 단계 2: 제목 입력
    else if (step == 2) {
      _schedulingState['data']['title'] = message;
      _schedulingState['step'] = 3;
      _addSystemMessage('언제로 일정을 잡을까요? (예: 내일, 이번 주 금요일, 2023-12-25)');
    }

    // 단계 3: 날짜 입력
    else if (step == 3) {
      // 날짜 파싱 시도
      DateTime? parsedDate = _parseDate(message);

      if (parsedDate == null) {
        _addSystemMessage('날짜 형식을 인식할 수 없습니다. 다시 입력해주세요. (예: 내일, 이번 주 금요일, 2023-12-25)');
        return;
      }

      _schedulingState['data']['date'] = parsedDate;
      _schedulingState['step'] = 4;
      _addSystemMessage('몇 시로 잡을까요? (예: 오전 9시, 오후 3시 30분, 14:00)');
    }

    // 단계 4: 시간 입력
    else if (step == 4) {
      // 시간 파싱 시도
      Map<String, dynamic>? timeData = _parseTime(message);

      if (timeData == null) {
        _addSystemMessage('시간 형식을 인식할 수 없습니다. 다시 입력해주세요. (예: 오전 9시, 오후 3시 30분, 14:00)');
        return;
      }

      _schedulingState['data']['startTime'] = timeData['startTime'];
      _schedulingState['data']['endTime'] = timeData['endTime'];

      // 일정 추가 처리
      final eventData = {
        'title': _schedulingState['data']['title'],
        'date': _schedulingState['data']['date'].toString().split(' ')[0],
        'time': _schedulingState['data']['startTime'],
        'endTime': _schedulingState['data']['endTime'],
      };

      // 일정 유형에 따라 다른 처리
      if (_schedulingState['type'] == 'calendar') {
        await _addEvent(eventData);
        _addSystemMessage('캘린더에 "${eventData['title']}" 일정이 추가되었습니다. ${_formatDate(eventData['date'])} ${eventData['time']}');
      } else {
        await _addTodo(eventData);
        _addSystemMessage('투두리스트에 "${eventData['title']}" 항목이 추가되었습니다. ${_formatDate(eventData['date'])} ${eventData['time']}');
      }

      // 일정 추가 완료, 상태 초기화
      _schedulingState = {
        'isScheduling': false,
        'type': null,
        'step': 0,
        'data': {},
      };
    }
  }

// 날짜 파싱 함수
  DateTime? _parseDate(String input) {
    final now = DateTime.now();
    final lowerInput = input.toLowerCase();

    // 상대적 날짜 처리
    if (lowerInput.contains('오늘')) {
      return DateTime(now.year, now.month, now.day);
    } else if (lowerInput.contains('내일')) {
      return DateTime(now.year, now.month, now.day + 1);
    } else if (lowerInput.contains('모레')) {
      return DateTime(now.year, now.month, now.day + 2);
    }

    // 요일 기반 처리 (이번 주, 다음 주)
    final weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

    for (var entry in weekdays.entries) {
      if (lowerInput.contains(entry.key)) {
        // 현재 요일
        int currentWeekday = now.weekday;
        int targetWeekday = entry.value;
        int daysToAdd;

        if (lowerInput.contains('다음 주')) {
          // 다음 주 해당 요일
          daysToAdd = 7 - currentWeekday + targetWeekday;
        } else {
          // 이번 주 해당 요일
          daysToAdd = targetWeekday - currentWeekday;
          if (daysToAdd <= 0) daysToAdd += 7; // 이미
        }

        return DateTime(now.year, now.month, now.day + daysToAdd);
      }
    }

    // YYYY-MM-DD 형식 파싱
    final dateRegex = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
    final match = dateRegex.firstMatch(input);

    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);

      return DateTime(year, month, day);
    }

    // MM/DD 형식 파싱 (현재 연도 가정)
    final shortDateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
    final shortMatch = shortDateRegex.firstMatch(input);

    if (shortMatch != null) {
      final month = int.parse(shortMatch.group(1)!);
      final day = int.parse(shortMatch.group(2)!);

      return DateTime(now.year, month, day);
    }

    // MM월 DD일 형식 파싱
    final koreanDateRegex = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final koreanMatch = koreanDateRegex.firstMatch(input);

    if (koreanMatch != null) {
      final month = int.parse(koreanMatch.group(1)!);
      final day = int.parse(koreanMatch.group(2)!);

      return DateTime(now.year, month, day);
    }

    return null; // 파싱 실패
  }

// 시간 파싱 함수
  Map<String, dynamic>? _parseTime(String input) {
    final lowerInput = input.toLowerCase();

    // 한국어 시간 형식 파싱 (오전 9시, 오후 3시 30분)
    final koreanTimeRegex = RegExp(r'(오전|오후)\s*(\d{1,2})시(?:\s*(\d{1,2})분)?');
    final koreanMatch = koreanTimeRegex.firstMatch(lowerInput);

    if (koreanMatch != null) {
      final ampm = koreanMatch.group(1);
      final hour = int.parse(koreanMatch.group(2)!);
      final minute = koreanMatch.group(3) != null ? int.parse(koreanMatch.group(3)!) : 0;

      int adjustedHour = hour;
      if (ampm == '오후' && hour < 12) {
        adjustedHour += 12;
      } else if (ampm == '오전' && hour == 12) {
        adjustedHour = 0;
      }

      // 시작 시간과 종료 시간 생성 (종료는 1시간 후로 가정)
      final startTime = '${adjustedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final endHour = (adjustedHour + 1) % 24;
      final endTime = '${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      return {
        'startTime': startTime,
        'endTime': endTime,
      };
    }

    // HH:MM 형식 파싱
    final timeRegex = RegExp(r'(\d{1,2}):(\d{1,2})');
    final match = timeRegex.firstMatch(input);

    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);

      // 시작 시간과 종료 시간 생성 (종료는 1시간 후로 가정)
      final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final endHour = (hour + 1) % 24;
      final endTime = '${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      return {
        'startTime': startTime,
        'endTime': endTime,
      };
    }

    // 시간만 입력된 경우 (9시, 3시)
    final hourOnlyRegex = RegExp(r'(\d{1,2})시');
    final hourMatch = hourOnlyRegex.firstMatch(input);

    if (hourMatch != null) {
      final hour = int.parse(hourMatch.group(1)!);

      // 시작 시간과 종료 시간 생성 (종료는 1시간 후로 가정)
      final startTime = '${hour.toString().padLeft(2, '0')}:00';
      final endHour = (hour + 1) % 24;
      final endTime = '${endHour.toString().padLeft(2, '0')}:00';

      return {
        'startTime': startTime,
        'endTime': endTime,
      };
    }

    return null; // 파싱 실패
  }

// 날짜 형식화 함수
  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return '${parts[0]}년 ${parts[1]}월 ${parts[2]}일';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildChatBubble(Map<String, dynamic> message, bool isUser) {
    // 메시지 내용에 단락 추가
    String formattedContent = message['content'];
    if (!isUser && formattedContent.length > 100) {
      // 긴 메시지의 경우, 문단 분리
      formattedContent = _formatLongMessage(formattedContent);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 80.0 : 16.0,
        right: isUser ? 16.0 : 80.0,
        top: 8.0,
        bottom: 8.0,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isUser
                ? Color(0xFFEEE6FF) // 매우 연한 파스텔 보라색
                : Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isUser ? Color(0xFFE6D9FF) : Colors.grey.shade200, // 연한 테두리
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            formattedContent,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 15,
              height: 1.4, // 줄 간격 증가
            ),
          ),
        ),
      ),
    );
  }

// 긴 메시지를 단락으로 나누는 함수
  String _formatLongMessage(String message) {
    // 기존 줄바꿈 유지
    if (message.contains('\n\n')) {
      return message; // 이미 단락이 있으면 그대로 반환
    }

    // 문장 단위로 분리
    final sentences = message.split(RegExp(r'(?<=[.!?])\s+'));

    if (sentences.length <= 3) {
      return message; // 문장이 적으면 그대로 반환
    }

    // 약 3문장마다 단락 추가
    final buffer = StringBuffer();
    for (int i = 0; i < sentences.length; i++) {
      buffer.write(sentences[i]);

      // 문장이 이미 마침표로 끝나는지 확인
      if (!sentences[i].trim().endsWith('.') &&
          !sentences[i].trim().endsWith('!') &&
          !sentences[i].trim().endsWith('?')) {
        buffer.write('.');
      }

      // 공백 추가
      buffer.write(' ');

      // 특정 갯수의 문장마다 단락 추가
      if ((i + 1) % 3 == 0 && i < sentences.length - 1) {
        buffer.write('\n\n');
      }
    }

    return buffer.toString();
  }

  // 로딩 인디케이터 위젯
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D8CFF)),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "메시지 작성 중...",
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptions() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildOptionButton("Create in-depth analysis", Icons.analytics, () {
            _handleQuickOptionTap({
              "text": "오늘의 일정 분석해줘",
              "action": "analyze_schedule"
            });
          }),
          SizedBox(width: 8),
          _buildOptionButton("Identify actionable tasks", Icons.task_alt, () {
            _handleQuickOptionTap({
              "text": "오늘 중요한 할 일 추천해줘",
              "action": "suggest_tasks"
            });
          }),
          SizedBox(width: 8),
          _buildOptionButton("일정 추가", Icons.add_circle_outline, () {
            _handleQuickOptionTap({
              "text": "일정 추가해줘",
              "action": "add_task"
            });
          }),
          SizedBox(width: 8),
          _buildOptionButton("일정 삭제", Icons.delete_outline, () {
            _handleQuickOptionTap({
              "text": "일정 삭제해줘",
              "action": "delete_task"
            });
          }),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFFBFBFB), // 거의 흰색에 가까운 매우 연한 회색
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100, width: 1), // 매우 연한 경계선
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.grey[500], // 더 연한 아이콘 색상
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                // 이모지/아이콘 제거됨
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF9D8CFF),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              tooltip: '메시지 보내기',
            ),
          ),
        ],
      ),
    );
  }


  // 옵션 아이콘 가져오기 함수
  Widget _getIconForOption(String? iconName) {
    IconData iconData;

    switch (iconName) {
      case 'calendar':
        iconData = Icons.calendar_today;
        break;
      case 'time':
        iconData = Icons.access_time;
        break;
      case 'bulb':
        iconData = Icons.lightbulb_outline;
        break;
      case 'book':
        iconData = Icons.book;
        break;
      case 'school':
        iconData = Icons.school;
        break;
      case 'flight':
        iconData = Icons.flight;
        break;
      case 'fitness':
        iconData = Icons.fitness_center;
        break;
      default:
        iconData = Icons.chat_bubble_outline;
    }

    return Icon(
      iconData,
      size: 18,
      color: const Color(0xFF9D8CFF),
    );
  }

  // 숫자 앞에 0 붙이기 (날짜 형식)
  String _padZero(int num) {
    return num.toString().padLeft(2, '0');
  }
}