
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
      // AI 서버 호출 (수정: AIAdviceService 사용)
      final aiResponse = await AIAdviceService.chatWithAssistant(
        message: text,
        calendar: widget.calendarData,
        tasks: widget.todoData,
        history: _chatHistory,
      );

      // 대화 기록 업데이트
      _chatHistory.add({"role": "user", "content": text});
      _chatHistory.add({"role": "assistant", "content": aiResponse});

      // 응답이 너무 길면 기록 정리 (선택사항)
      if (_chatHistory.length > 10) {
        _chatHistory = _chatHistory.sublist(_chatHistory.length - 10);
      }

      setState(() {
        _isTyping = false;
        _addBotMessage(aiResponse);
      });
    } catch (e) {
      print("AI 응답 처리 중 오류: $e");
      setState(() {
        _isTyping = false;
        _addBotMessage("죄송합니다. 응답을 처리하는 중에 오류가 발생했습니다. 다시 시도해 주세요.");
      });
    }

    _scrollToBottom();
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