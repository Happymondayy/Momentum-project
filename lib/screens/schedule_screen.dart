import 'package:flutter/material.dart';
import '../services/api_service.dart'; // 위에서 만든 ApiService 파일

class ScheduleScreen extends StatefulWidget {
  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = false;
  List<dynamic> _scheduleData = [];
  String _errorMessage = '';

  // 1. 일정 생성 예시
  Future<void> _createSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // 샘플 데이터
    List<Map<String, dynamic>> tasks = [
      {
        'title': '프로젝트 완료',
        'importance': 3,
        'urgency': 3,
        'dueDate': '2025-05-25',
        'time': '14:00',
        'endTime': '16:00',
      },
      {
        'title': '운동하기',
        'importance': 2,
        'urgency': 1,
        'dueDate': '2025-05-22',
      },
    ];

    List<Map<String, dynamic>> calendar = [
      {
        'title': '회의',
        'date': '2025-05-22',
        'startTime': '10:00',
        'endTime': '11:00',
        'location': '회의실 A',
      },
    ];

    final result = await ApiService.createSchedule(
      tasks: tasks,
      calendar: calendar,
    );

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _scheduleData = result['data'];
        print('일정 생성 성공: $_scheduleData');
      } else {
        _errorMessage = result['error'];
        print('일정 생성 실패: ${result['error']}');
      }
    });
  }

  // 2. AI 조언 받기 예시
  Future<void> _getAdvice() async {
    setState(() {
      _isLoading = true;
    });

    List<Map<String, dynamic>> tasks = [
      {
        'title': '중요한 프레젠테이션 준비',
        'importance': 3,
        'urgency': 3,
        'dueDate': '2025-05-23',
      },
    ];

    List<Map<String, dynamic>> calendar = [
      {
        'title': '팀 미팅',
        'date': '2025-05-22',
        'startTime': '14:00',
        'endTime': '15:00',
      },
    ];

    final result = await ApiService.getAdvice(
      tasks: tasks,
      calendar: calendar,
      preferences: {
        'workingHours': '09:00-18:00',
        'preferredBreakTime': 60,
      },
    );

    setState(() {
      _isLoading = false;
      if (result['success']) {
        final advice = result['data'];
        print('AI 조언: ${advice['messages']}');
        // 조언을 UI에 표시
        _showAdviceDialog(advice['messages']);
      } else {
        _errorMessage = result['error'];
      }
    });
  }

  // 3. 챗봇과 대화 예시
  Future<void> _chatWithBot(String message) async {
    final result = await ApiService.chatWithBot(
      message: message,
      context: {
        'tasks': [
          {
            'title': '숙제하기',
            'importance': 2,
            'urgency': 3,
            'dueDate': '2025-05-23',
          }
        ],
        'calendar': [],
      },
      history: [
        {
          'role': 'user',
          'message': '안녕하세요',
        },
        {
          'role': 'assistant',
          'message': '안녕하세요! 무엇을 도와드릴까요?',
        },
      ],
    );

    if (result['success']) {
      final chatResponse = result['data'];
      print('챗봇 응답: ${chatResponse['response']}');
      print('액션: ${chatResponse['actions']}');
    } else {
      print('챗봇 오류: ${result['error']}');
    }
  }

  // 4. 대시보드 메시지 받기 예시
  Future<void> _getDashboardMessage() async {
    final result = await ApiService.getDashboardMessage(
      tasks: [
        {
          'title': '보고서 작성',
          'importance': 3,
          'urgency': 2,
          'isCompleted': false,
        }
      ],
      calendar: [
        {
          'title': '의사 약속',
          'date': '2025-05-22',
          'startTime': '15:00',
          'endTime': '16:00',
        }
      ],
    );

    if (result['success']) {
      final messages = result['data']['messages'];
      print('대시보드 메시지: $messages');
    }
  }

  void _showAdviceDialog(List<dynamic> messages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('AI 조언'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(messages[index].toString()),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('스케줄 관리'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isLoading)
              CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: _createSchedule,
                child: Text('일정 생성'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getAdvice,
                child: Text('AI 조언 받기'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _chatWithBot('오늘 할 일을 추천해주세요'),
                child: Text('챗봇과 대화'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getDashboardMessage,
                child: Text('대시보드 메시지'),
              ),
            ],

            if (_errorMessage.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 20),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '오류: $_errorMessage',
                  style: TextStyle(color: Colors.red[800]),
                ),
              ),

            if (_scheduleData.isNotEmpty)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  child: ListView.builder(
                    itemCount: _scheduleData.length,
                    itemBuilder: (context, index) {
                      final item = _scheduleData[index];
                      return Card(
                        child: ListTile(
                          title: Text(item['title'] ?? ''),
                          subtitle: Text(
                            '시간: ${item['time']} - ${item['endTime']}\n'
                                '우선순위: ${item['priority']}\n'
                                '설명: ${item['description']}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}