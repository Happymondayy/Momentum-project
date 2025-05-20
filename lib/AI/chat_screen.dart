
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

    // 오늘 캘린더 일정 가져오기
    final todayEvents = widget.calendarData.where((event) {
      return event['date'] == today || (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    // 오늘 할 일 목록 가져오기
    final todayTasks = widget.todoData.where((task) {
      return task['date'] == today || (task['date'] != null && task['date'].startsWith(today));
    }).toList();

    // 미완료 할 일 개수 계산
    final incompleteTasks = todayTasks.where((task) => task['isCompleted'] != true).length;

    // 브리핑 메시지 생성 - 더 친근하게 수정
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

    // 일정 요약
    if (todayEvents.isNotEmpty) {
      message += "📅 오늘의 일정 (${todayEvents.length}개):\n";
      for (int i = 0; i < min(3, todayEvents.length); i++) {
        final event = todayEvents[i];
        String timeInfo = "";
        if (event['startTime'] != null && event['startTime'] is Map) {
          final startHour = event['startTime']['hour'] ?? 0;
          final startMinute = event['startTime']['minute'] ?? 0;
          timeInfo = "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}";
        }

        message += "• ${event['title']}${timeInfo.isNotEmpty ? ' ($timeInfo)' : ''}\n";
      }

      if (todayEvents.length > 3) {
        message += "  외 ${todayEvents.length - 3}개 일정이 있어요.\n";
      }

      message += "\n";
    } else {
      message += "📅 오늘은 특별한 일정이 없네요! 여유로운 하루를 보내세요.\n\n";
    }

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

  // 추천 일정 대화상자 표시 함수 (기존 코드 수정)
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

  // 일정 추가 함수
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
      final eventId = _uuid.v4();

// Firestore에 저장할 데이터 준비
      final eventDocData = {
        'id': eventId,
        'userId': widget.userId,
        'title': eventData['title'],
        'date': Timestamp.fromDate(eventDate),
        'startTime': startTime != null ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}' : null,
        'endTime': endTime != null ? '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}' : null,
        'location': eventData['location'] ?? '',
        'description': eventData['description'] ?? eventData['memo'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'color': eventData['color'] ?? '#9D8CFF', // 기본 색상
        'isCompleted': false,
      };

// Firestore에 저장
      await _firestore.collection('events').doc(eventId).set(eventDocData);

// 부모에게 이벤트 추가 알림
      widget.onEventAdded(eventDocData);

// 성공 메시지
      _addSystemMessage("'${eventData['title']}' 일정이 추가되었습니다.");
    } catch (e) {
      print('일정 추가 오류: $e');
      _addSystemMessage("일정 추가 중 오류가 발생했습니다: $e");
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
        title: Text(_isOfflineMode ? 'AI 비서 (오프라인 모드)' : 'AI 비서'),
        backgroundColor: const Color(0xFF9D8CFF),
        foregroundColor: Colors.white,
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
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _initializeChatService();
            },
            tooltip: '연결 새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
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

                return Padding(
                  padding: EdgeInsets.only(
                    left: isUser ? 40.0 : 16.0,
                    right: isUser ? 16.0 : 40.0,
                    top: 8.0,
                    bottom: 8.0,
                  ),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF9D8CFF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message['content'],
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
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
            ),

          // 빠른 옵션 말풍선 UI 추가
          if (_quickOptions.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _quickOptions.length,
                itemBuilder: (context, index) {
                  final option = _quickOptions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _handleQuickOptionTap(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E0FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF9D8CFF), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _getIconForOption(option['icon']),
                            const SizedBox(width: 8),
                            Text(
                              option['text'],
                              style: const TextStyle(
                                color: Color(0xFF4A4A4A),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 입력 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
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
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF5F3FF),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF9D8CFF),
                        size: 20,
                      ),
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
}