import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 대화 메시지 모델
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> calendarData;
  final List<Map<String, dynamic>> todoData;

  const ChatScreen({Key? key, required this.calendarData, required this.todoData}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final userInput = _inputController.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: userInput, isUser: true));
      _isLoading = true;
      _inputController.clear();
    });

    try {
      final aiReply = await fetchAIReply(widget.calendarData, widget.todoData);
      setState(() {
        _messages.add(ChatMessage(text: aiReply, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'AI 서버 오류가 발생했습니다.', isUser: false));
        _isLoading = false;
      });
    }
  }

  Future<String> fetchAIReply(List<Map<String, dynamic>> calendarData, List<Map<String, dynamic>> todoData) async {
    final url = Uri.parse('http://192.168.219.110:5001/analyze');  // 여기 IP 꼭 수정하세요!

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "calendar": calendarData,
        "todo": todoData,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'] ?? '응답이 없습니다.';
    } else {
      throw Exception('AI 서버 오류: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 플래너 챗봇')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              reverse: true,
              padding: EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: '궁금한 점을 입력하세요...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child: Text('전송'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
