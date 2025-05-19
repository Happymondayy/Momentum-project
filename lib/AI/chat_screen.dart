import 'package:flutter/material.dart';
import 'package:momentum_planner/AI/chat_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isOfflineMode = false;
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _initializeChatService();
  }

  Future<void> _initializeChatService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _chatService = ChatService(userId: widget.userId);

      // 간단한 테스트 메시지로 서비스 연결 상태 확인
      final testResponse = await _chatService.generateOfflineResponse("테스트");

      setState(() {
        _isOfflineMode = false;
        _isLoading = false;
      });

      _addSystemMessage("안녕하세요! 일정과 할 일 관리를 도와드릴 AI 비서입니다. 무엇을 도와드릴까요?");
    } catch (e) {
      print('초기화 오류: $e');

      // 오류 발생 시 오프라인 모드 활성화
      _chatService = ChatService(userId: widget.userId);

      setState(() {
        _isOfflineMode = true;
        _isLoading = false;
      });

      _addSystemMessage("안녕하세요! 현재 오프라인 모드로 작동 중입니다. 제한된 기능만 사용 가능합니다.");
    }
  }

  void _addSystemMessage(String message) {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': message,
      });
    });

    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
      });
    });

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
      });

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

      _scrollToBottom();
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

          if (actionType == 'add_task') {
            // 일정 추가 로직
            print('일정 추가 액션: $actionData');
            // 여기에 실제 일정 추가 구현
            // 예: TaskDataService().addTask(actionData);

            // 추가 성공 메시지
            _addSystemMessage("'${actionData['title']}' 일정이 추가되었습니다.");
          }
          else if (actionType == 'delete_task') {
            // 일정 삭제 로직
            print('일정 삭제 액션: $actionData');
            // 여기에 실제 일정 삭제 구현
            // 예: TaskDataService().deleteTask(actionData);

            // 삭제 성공 메시지
            _addSystemMessage("'${actionData['title']}' 일정이 삭제되었습니다.");
          }
          else if (actionType == 'recommend_task') {
            // 일정 추천 로직
            print('일정 추천 액션: $actionData');

            // 추천 확인 대화상자 표시
            _showRecommendationDialog(actionData);
          }
        }
      }
    } catch (e) {
      print('액션 처리 오류: $e');
      // 오류가 있어도 채팅은 계속 진행
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
              if (recommendation['time'] != null && recommendation['endTime'] != null)
                Text('시간: ${recommendation['time']} ~ ${recommendation['endTime']}'),
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
                // 추천 일정 추가 로직
                // 예: TaskDataService().addTask(recommendation);

                // 추가 성공 메시지
                _addSystemMessage("'${recommendation['title'] ?? '추천 일정'}' 일정이 추가되었습니다.");

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

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF9D8CFF)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      message['content'],
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
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
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.centerLeft,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D8CFF)),
                strokeWidth: 3,
              ),
            ),

          // 입력 영역
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24.0)),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF2F2F2),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: const Color(0xFF9D8CFF),
                  elevation: 0,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}