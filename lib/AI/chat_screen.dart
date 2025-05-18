
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'chat_service.dart';
import 'ai_advice_service.dart';

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> calendarData;
  final List<Map<String, dynamic>> todoData;
  final String userId;

  const ChatScreen({
    Key? key,
    required this.calendarData,
    required this.todoData,
    required this.userId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _sendInitialGreeting();

    // 디버깅: 데이터 확인
    print('ChatScreen 초기화 - 캘린더 데이터: ${jsonEncode(widget.calendarData)}');
    print('ChatScreen 초기화 - 할일 데이터: ${jsonEncode(widget.todoData)}');
  }

  void _sendInitialGreeting() {
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _isTyping = true;
      });
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          _isTyping = false;
          _addBotMessage(_generateInitialGreeting());
        });
        _scrollToBottom();
      });
    });
  }

  String _generateInitialGreeting() {
    final now = DateTime.now();
    final formattedDate = "${now.year}년 ${now.month}월 ${now.day}일";
    String greeting = "안녕하세요! 👋 $formattedDate의 AI 비서입니다.\n\n";

    if (widget.calendarData.isEmpty && widget.todoData.isEmpty) {
      greeting += "오늘은 등록된 일정이나 할 일이 없네요. 무엇을 도와드릴까요?";
    } else {
      if (widget.calendarData.isNotEmpty) {
        greeting += "오늘 ${widget.calendarData.length}개의 일정이 있습니다.\n";
      }
      if (widget.todoData.isNotEmpty) {
        greeting += "또한 ${widget.todoData.length}개의 할 일이 있습니다.\n";
        int completedTasks = widget.todoData.where((task) => task['isCompleted'] == true).length;
        if (completedTasks > 0) {
          greeting += "현재 $completedTasks개의 할 일을 완료하셨습니다. 👍\n";
        }
      }
      greeting += "\n일정 관리, 시간 관리 조언, 또는 오늘의 할 일에 대한 도움이 필요하신가요?";
    }
    return greeting;
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();

    setState(() {
      _addUserMessage(text);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // 중요: 여기에서 데이터 형식 표준화 로직 추가
      List<Map<String, dynamic>> sanitizedCalendar = _sanitizeCalendarData(widget.calendarData);
      List<Map<String, dynamic>> sanitizedTasks = _sanitizeTaskData(widget.todoData);

      // AI 서버 호출
      final aiResponse = await AIAdviceService.chatWithAssistant(
        message: text,
        calendar: sanitizedCalendar,
        tasks: sanitizedTasks,
        history: _chatHistory,
      );

      // 대화 기록 업데이트
      _chatHistory.add({"role": "user", "content": text});
      _chatHistory.add({"role": "assistant", "content": aiResponse});

      // 응답이 너무 길면 기록 정리
      if (_chatHistory.length > 10) {
        _chatHistory = _chatHistory.sublist(_chatHistory.length - 10);
      }

      setState(() {
        _isTyping = false;
        _addBotMessage(aiResponse);
      });
    } catch (e) {
      print("AI 응답 처리 중 오류: $e");

      // 오류가 발생했을 때 일정과 기본 정보를 바탕으로 대체 응답 생성
      String fallbackResponse = _generateFallbackResponse(text);

      setState(() {
        _isTyping = false;
        _addBotMessage(fallbackResponse);
      });
    }

    _scrollToBottom();
  }

// 데이터 형식 표준화 함수들
  List<Map<String, dynamic>> _sanitizeCalendarData(List<Map<String, dynamic>> calendar) {
    return calendar.map((event) {
      return {
        "id": event["id"] ?? "cal_${DateTime.now().millisecondsSinceEpoch}",
        "title": event["title"] ?? "무제",
        "date": event["date"] ?? DateTime.now().toString().split(' ')[0],
        "startTime": event["startTime"],
        "endTime": event["endTime"],
        "location": event["location"] ?? "",
        "description": event["description"] ?? "",
      };
    }).toList();
  }

  List<Map<String, dynamic>> _sanitizeTaskData(List<Map<String, dynamic>> tasks) {
    return tasks.map((task) {
      return {
        "id": task["id"] ?? "task_${DateTime.now().millisecondsSinceEpoch}",
        "title": task["title"] ?? "무제 할 일",
        "dueDate": task["dueDate"] ?? "없음",
        "importance": task["importance"]?.toString() ?? "1",
        "urgency": task["urgency"]?.toString() ?? "1",
        "isCompleted": task["isCompleted"] ?? false,
      };
    }).toList();
  }

// 오류 발생 시 대체 응답 생성 함수
  String _generateFallbackResponse(String userMessage) {
    // 간단한 키워드 기반 응답
    final lowerMessage = userMessage.toLowerCase();

    // '오늘 뭐해야 좋을까?' 같은 질문에 대한 처리
    if (lowerMessage.contains('뭐해') ||
        lowerMessage.contains('뭐 해') ||
        lowerMessage.contains('할까') ||
        lowerMessage.contains('좋을까')) {

      // 일정이 있는지 확인
      if (widget.calendarData.isNotEmpty) {
        String response = "오늘 일정을 확인해보니 다음과 같은 일정이 있어요:\n\n";
        for (int i = 0; i < min(3, widget.calendarData.length); i++) {
          response += "- ${widget.calendarData[i]['title']}\n";
        }
        response += "\n이 일정들을 우선 처리하는 것이 좋을 것 같아요.";
        return response;
      }

      // 할 일이 있는지 확인
      else if (widget.todoData.isNotEmpty) {
        String response = "오늘 할 일 목록을 확인해보니 다음과 같은 할 일이 있어요:\n\n";
        for (int i = 0; i < min(3, widget.todoData.length); i++) {
          response += "- ${widget.todoData[i]['title']}\n";
        }
        response += "\n이 할 일들을 처리하는 것이 좋을 것 같아요.";
        return response;
      }

      // 일정과 할 일이 모두 없는 경우
      else {
        return "오늘은 특별히 예정된 일정이나 할 일이 없네요. 취미 활동을 하거나, 독서, 운동 등 자기계발 시간을 가져보는 건 어떨까요?";
      }
    }

    // 기본 응답
    return "죄송합니다. 지금은 서버 연결에 문제가 있어 자세한 답변을 드리기 어렵습니다. 잠시 후 다시 시도해주세요.";
  }

  void _addUserMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: true));
  }

  void _addBotMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: false));
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF373775),
        title: Text('AI 비서', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Color(0xFFF5F5F5),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16.0),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return TypingIndicator();
                  }
                  return _messages[index];
                },
              ),
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFFEEEDFA),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          SizedBox(width: 8.0),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF373775),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: () => _handleSubmitted(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(),
          if (!isUser) SizedBox(width: 8.0),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser ? Color(0xFF373775) : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15.0,
                ),
              ),
            ),
          ),
          if (isUser) SizedBox(width: 8.0),
          if (isUser)
            CircleAvatar(
              backgroundColor: Color(0xFFEEEDFA),
              child: Icon(
                Icons.person,
                color: Color(0xFF373775),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      backgroundColor: Color(0xFFEEEDFA),
      child: Icon(
        Icons.assistant,
        color: Color(0xFF373775),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFEEEDFA),
            child: Icon(
              Icons.assistant,
              color: Color(0xFF373775),
            ),
          ),
          SizedBox(width: 8.0),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(
                3,
                    (index) => AnimatedDot(
                  controller: _controller,
                  delay: Duration(milliseconds: index * 200),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedDot extends StatelessWidget {
  final AnimationController controller;
  final Duration delay;

  AnimatedDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: DelayTween(begin: 0.2, end: 1.0, delay: delay).animate(controller),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF373775)),
      ),
    );
  }
}

class DelayTween extends Tween<double> {
  final Duration delay;

  DelayTween({double? begin, double? end, required this.delay})
      : super(begin: begin ?? 0, end: end ?? 1);

  @override
  double lerp(double t) {
    final delayedT = (t - delay.inMilliseconds / 1200).clamp(0.0, 1.0);
    return super.lerp(delayedT);
  }
}