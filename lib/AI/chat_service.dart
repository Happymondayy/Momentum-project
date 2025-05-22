import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static String get _apiUrl => 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';
  late final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _apiKey;

  // 일정 추가 상태 관리
  Map<String, dynamic> _schedulingState = {
    'isScheduling': false,
    'step': 0, // 0: 시작, 1: 제목, 2: 날짜, 3: 시간, 4: 완료
    'data': {},
    'type': null, // 'calendar' 또는 'todo'
  };

  ChatService({required this.userId}) {
    _apiKey = "AIzaSyDNfd7f0Bgg0K1d_95HXMMvUXiQ9FqdkRQ";
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final apiKeyDoc = await _firestore.collection('config').doc('api_keys').get();
      final firebaseKey = apiKeyDoc.data()?['gemini_api_key'] ?? '';
      if (firebaseKey.isNotEmpty) {
        _apiKey = firebaseKey;
        print('Firebase에서 API 키 로드 성공');
      }
    } catch (e) {
      print('Firebase API 키 로드 중 오류: $e');
    }
  }

  // 일정 추가 요청 감지
  bool _isScheduleAddRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return (lowerMessage.contains('일정') || lowerMessage.contains('할 일') ||
        lowerMessage.contains('이벤트') || lowerMessage.contains('약속')) &&
        (lowerMessage.contains('추가') || lowerMessage.contains('만들') ||
            lowerMessage.contains('저장') || lowerMessage.contains('등록') ||
            lowerMessage.contains('생성'));
  }

  // 자연어 날짜 파싱
  DateTime? _parseNaturalDate(String input) {
    final now = DateTime.now();
    final lowerInput = input.toLowerCase().trim();

    // 상대적 날짜
    if (lowerInput.contains('오늘')) {
      return DateTime(now.year, now.month, now.day);
    } else if (lowerInput.contains('내일')) {
      return DateTime(now.year, now.month, now.day + 1);
    } else if (lowerInput.contains('모레')) {
      return DateTime(now.year, now.month, now.day + 2);
    }

    // 요일 처리
    final weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

    for (var entry in weekdays.entries) {
      if (lowerInput.contains('${entry.key}요일') || lowerInput.contains(entry.key)) {
        int currentWeekday = now.weekday;
        int targetWeekday = entry.value;
        int daysToAdd;

        if (lowerInput.contains('다음 주') || lowerInput.contains('다음주')) {
          daysToAdd = 7 - currentWeekday + targetWeekday;
        } else {
          daysToAdd = targetWeekday - currentWeekday;
          if (daysToAdd <= 0) daysToAdd += 7;
        }

        return DateTime(now.year, now.month, now.day + daysToAdd);
      }
    }

    // YYYY-MM-DD 형식
    final dateRegex = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})');
    final dateMatch = dateRegex.firstMatch(input);
    if (dateMatch != null) {
      return DateTime(
          int.parse(dateMatch.group(1)!),
          int.parse(dateMatch.group(2)!),
          int.parse(dateMatch.group(3)!)
      );
    }

    // MM월 DD일 형식
    final koreanDateRegex = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final koreanMatch = koreanDateRegex.firstMatch(input);
    if (koreanMatch != null) {
      return DateTime(
          now.year,
          int.parse(koreanMatch.group(1)!),
          int.parse(koreanMatch.group(2)!)
      );
    }

    // MM/DD 형식
    final shortDateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
    final shortMatch = shortDateRegex.firstMatch(input);
    if (shortMatch != null) {
      return DateTime(
          now.year,
          int.parse(shortMatch.group(1)!),
          int.parse(shortMatch.group(2)!)
      );
    }

    return null;
  }

  // 자연어 시간 파싱
  Map<String, String>? _parseNaturalTime(String input) {
    final lowerInput = input.toLowerCase().trim();

    // 오전/오후 시간 (예: 오후 3시, 오전 9시 30분)
    final koreanTimeRegex = RegExp(r'(오전|오후)\s*(\d{1,2})시(?:\s*(\d{1,2})분)?');
    final koreanMatch = koreanTimeRegex.firstMatch(lowerInput);

    if (koreanMatch != null) {
      final ampm = koreanMatch.group(1);
      int hour = int.parse(koreanMatch.group(2)!);
      final minute = koreanMatch.group(3) != null ? int.parse(koreanMatch.group(3)!) : 0;

      if (ampm == '오후' && hour < 12) hour += 12;
      if (ampm == '오전' && hour == 12) hour = 0;

      final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final endTime = '${((hour + 1) % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      return {'startTime': startTime, 'endTime': endTime};
    }

    // 24시간 형식 (예: 15시, 14:30)
    final time24Regex = RegExp(r'(\d{1,2}):?(\d{0,2})시?');
    final time24Match = time24Regex.firstMatch(input);

    if (time24Match != null) {
      final hour = int.parse(time24Match.group(1)!);
      final minute = time24Match.group(2)!.isEmpty ? 0 : int.parse(time24Match.group(2)!);

      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        final endTime = '${((hour + 1) % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

        return {'startTime': startTime, 'endTime': endTime};
      }
    }

    return null;
  }

  // 대화형 일정 추가 처리
  Map<String, dynamic> _processSchedulingStep(String message) {
    final step = _schedulingState['step'];

    switch (step) {
      case 0: // 일정 추가 시작
        if (_isScheduleAddRequest(message)) {
          _schedulingState['isScheduling'] = true;
          _schedulingState['step'] = 1;
          _schedulingState['data'] = {};

          return {
            "response": "어떤 일정을 추가하시겠어요? 먼저 일정의 제목을 알려주세요.\n\n예시: '팀 회의', '병원 예약', '친구 만나기'",
            "actions": [],
            "isScheduling": true
          };
        }
        break;

      case 1: // 제목 입력
        _schedulingState['data']['title'] = message.trim();
        _schedulingState['step'] = 2;

        return {
          "response": "\"${message}\" 일정이군요! 언제로 잡을까요?\n\n예시: '내일', '이번 주 금요일', '5월 25일', '오늘'",
          "actions": [],
          "isScheduling": true
        };

      case 2: // 날짜 입력
        final parsedDate = _parseNaturalDate(message);

        if (parsedDate == null) {
          return {
            "response": "날짜를 정확히 알아듣지 못했어요. 다시 말씀해주세요.\n\n예시: '내일', '이번 주 금요일', '5월 25일'",
            "actions": [],
            "isScheduling": true
          };
        }

        _schedulingState['data']['date'] = parsedDate;
        _schedulingState['step'] = 3;

        final dateStr = '${parsedDate.month}월 ${parsedDate.day}일';
        return {
          "response": "${dateStr}로 잡겠습니다! 몇 시에 하시겠어요?\n\n예시: '오후 3시', '오전 10시 30분', '14:00'\n\n(시간을 정하지 않으려면 '시간 없음'이라고 말씀해주세요)",
          "actions": [],
          "isScheduling": true
        };

      case 3: // 시간 입력
        if (message.toLowerCase().contains('시간 없음') ||
            message.toLowerCase().contains('없음') ||
            message.toLowerCase().contains('하루종일')) {
          // 시간 없는 일정
          _schedulingState['data']['startTime'] = null;
          _schedulingState['data']['endTime'] = null;
          _schedulingState['data']['isAllDay'] = true;
        } else {
          final parsedTime = _parseNaturalTime(message);

          if (parsedTime == null) {
            return {
              "response": "시간을 정확히 알아듣지 못했어요. 다시 말씀해주세요.\n\n예시: '오후 3시', '오전 10시 30분', '14:00'\n\n(시간을 정하지 않으려면 '시간 없음'이라고 말씀해주세요)",
              "actions": [],
              "isScheduling": true
            };
          }

          _schedulingState['data']['startTime'] = parsedTime['startTime'];
          _schedulingState['data']['endTime'] = parsedTime['endTime'];
          _schedulingState['data']['isAllDay'] = false;
        }

        // 일정 추가 완료
        final eventData = Map<String, dynamic>.from(_schedulingState['data']);

        // 상태 초기화
        _schedulingState = {
          'isScheduling': false,
          'step': 0,
          'data': {},
          'type': null,
        };

        // 성공 메시지 생성
        final title = eventData['title'];
        final date = eventData['date'] as DateTime;
        final dateStr = '${date.year}년 ${date.month}월 ${date.day}일';

        String timeStr = '';
        if (eventData['isAllDay'] == true) {
          timeStr = ' (하루종일)';
        } else if (eventData['startTime'] != null) {
          final startTime = eventData['startTime'];
          timeStr = ' ${startTime}';
        }

        return {
          "response": "✅ \"${title}\" 일정이 ${dateStr}${timeStr}에 추가되었습니다!\n\n일정이 캘린더에 반영되었어요. 다른 도움이 필요하시면 언제든 말씀해주세요!",
          "actions": [
            {
              "action": "add_task",
              "data": {
                "title": eventData['title'],
                "date": date.toString().split(' ')[0],
                "time": eventData['startTime'],
                "endTime": eventData['endTime'],
                "isAllDay": eventData['isAllDay'] ?? false,
                "type": "calendar"
              }
            }
          ],
          "isScheduling": false
        };

      default:
      // 상태 초기화
        _schedulingState = {
          'isScheduling': false,
          'step': 0,
          'data': {},
          'type': null,
        };
        break;
    }

    return {
      "response": "죄송해요, 다시 처음부터 시작해주세요. '일정 추가해줘'라고 말씀해주시면 도와드릴게요!",
      "actions": [],
      "isScheduling": false
    };
  }

  // 기존 chatWithAssistant 메서드 수정
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
    String? action,
  }) async {
    try {
      // 일정 추가 중인지 확인
      if (_schedulingState['isScheduling'] == true || _isScheduleAddRequest(message)) {
        return _processSchedulingStep(message);
      }

      // API 키 확인
      if (_apiKey.isEmpty) {
        return generateOfflineResponse(message, calendar, tasks);
      }

      // 현재 날짜 및 시간
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 대화 기록 형식화
      final List<Map<String, dynamic>> formattedHistory = [];
      for (var msg in history) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        formattedHistory.add({
          "role": role,
          "parts": [{"text": msg['content']}]
        });
      }

      // 초기 프롬프트
      final initialPrompt = '''
당신은 일정 관리 앱의 AI 비서입니다. 사용자의 일정과 할 일을 관리하고, 시간 관리에 도움을 주며, 일정을 추천합니다.

오늘 날짜: $formattedDate

사용자의 캘린더 일정:
${jsonEncode(calendar)}

사용자의 할 일 목록:
${jsonEncode(tasks)}

사용자의 메시지에 대한 응답으로 일정 관리와 관련된 작업을 수행할 수 있습니다:
1. 일정 추가: 사용자가 일정 추가를 요청하면, 일정의 세부 정보를 확인하고 추가합니다.
2. 일정 삭제: 사용자가 일정 삭제를 요청하면, 삭제할 일정을 확인하고 삭제합니다.
3. 일정 추천: 사용자의 빈 시간에 맞는 일정을 추천합니다.
4. 시간 관리 조언: 사용자의 일정을 분석하여 효율적인 시간 관리 조언을 제공합니다.

응답은 항상 다음과 같은 JSON 형식을 포함해야 합니다:
{
  "response": "사용자에게 보여줄 텍스트 응답",
  "actions": [
    {
      "action": "액션 타입 (add_task, delete_task, recommend_task 등)",
      "data": {
        // 액션에 필요한 데이터 (일정 제목, 날짜, 시간 등)
      }
    }
  ]
}

액션 타입:
- add_task: 새 일정 추가 (필수 필드: title, date)
- delete_task: 일정 삭제 (필수 필드: title 또는 id)
- recommend_task: 일정 추천 (필수 필드: title, description)

사용자가 "오늘 할 일"이나 "내 일정" 등을 물으면 구체적으로 답변하고, 절대 스스로 생각해보라고 하지 마세요.
항상 친절하고 도움이 되도록 대화하며, 한국어로 응답하세요.
''';

      // 대화 설정
      List<Map<String, dynamic>> conversationContents = [];

      if (formattedHistory.isNotEmpty) {
        conversationContents.addAll(formattedHistory);
      } else {
        conversationContents.add({
          "role": "user",
          "parts": [{"text": "안녕하세요. 도움이 필요합니다."}]
        });

        conversationContents.add({
          "role": "model",
          "parts": [{"text": initialPrompt}]
        });
      }

      conversationContents.add({
        "role": "user",
        "parts": [{"text": message}]
      });

      // API 요청 데이터
      final requestData = {
        "contents": conversationContents,
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 2048,
        }
      };

      // API 요청 보내기
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        try {
          final jsonStart = text.indexOf('{');
          final jsonEnd = text.lastIndexOf('}') + 1;

          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonString = text.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> parsedResponse = Map<String, dynamic>.from(json.decode(jsonString));

            if (!parsedResponse.containsKey('actions')) {
              parsedResponse['actions'] = <Map<String, dynamic>>[];
            } else {
              final actions = parsedResponse['actions'];
              if (actions is List) {
                parsedResponse['actions'] = List<Map<String, dynamic>>.from(
                    actions.map((action) => Map<String, dynamic>.from(action))
                );
              }
            }

            return parsedResponse;
          } else {
            return {
              "response": text,
              "actions": <Map<String, dynamic>>[]
            };
          }
        } catch (e) {
          print('JSON 파싱 오류: $e');
          return {
            "response": text,
            "actions": <Map<String, dynamic>>[]
          };
        }
      }

      throw Exception('API 요청 실패: ${response.statusCode}');
    } catch (e) {
      print('AI 응답 처리 중 오류: $e');
      return generateOfflineResponse(message, calendar, tasks);
    }
  }

  // 오프라인 응답 생성 (기존 코드 유지)
  Map<String, dynamic> generateOfflineResponse(String message, [List<Map<String, dynamic>>? calendar, List<Map<String, dynamic>>? tasks]) {
    message = message.toLowerCase();
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    Map<String, dynamic> response = {
      "response": "현재 서버 연결이 원활하지 않아 기본 응답만 제공할 수 있습니다. 인터넷 연결을 확인해주세요.",
      "actions": []
    };

    if (message.contains("안녕") || message.contains("반가워")) {
      response["response"] = "안녕하세요! 오늘도 좋은 하루 되세요. (오프라인 모드)";
    }
    else if (message.contains("일정") && message.contains("추가")) {
      response["response"] = "일정을 추가하려면 제목, 날짜, 시간 정보가 필요합니다. 예: '내일 3시에 미팅 일정 추가해줘' (오프라인 모드)";
    }
    else if (message.contains("오늘") &&
        (message.contains("할 일") || message.contains("일정") || message.contains("뭐") ||
            message.contains("해야") || message.contains("브리핑"))) {

      String responseMsg = "오늘의 일정과 할 일을 알려드릴게요.\n\n";

      if (calendar != null && tasks != null) {
        final todayEvents = calendar.where((event) =>
        event['date'] == today ||
            (event['date'] != null && event['date'].toString().startsWith(today))
        ).toList();

        final todayTodos = tasks.where((todo) =>
        todo['date'] == today ||
            (todo['date'] != null && todo['date'].toString().startsWith(today))
        ).toList();

        if (todayEvents.isEmpty && todayTodos.isEmpty) {
          responseMsg = "오늘은 등록된 일정이 없네요. 새로운 일정을 추가하시겠어요?";
        } else {
          if (todayEvents.isNotEmpty) {
            responseMsg += "📅 캘린더 일정:\n";
            for (var event in todayEvents) {
              String timeInfo = "";
              if (event['startTime'] != null) {
                if (event['startTime'] is Map) {
                  final hour = event['startTime']['hour'] ?? 0;
                  final minute = event['startTime']['minute'] ?? 0;
                  timeInfo = " (${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})";
                } else if (event['startTime'] is String && event['startTime'].toString().isNotEmpty) {
                  timeInfo = " (${event['startTime']})";
                }
              }
              responseMsg += "• ${event['title']}$timeInfo\n";
            }
            responseMsg += "\n";
          }

          if (todayTodos.isNotEmpty) {
            responseMsg += "📝 오늘의 할 일:\n";
            int completedCount = 0;

            for (var todo in todayTodos) {
              if (todo['isCompleted'] == true) {
                completedCount++;
              }

              String completedMark = todo['isCompleted'] == true ? "✓ " : "";
              String timeInfo = "";
              if (todo['time'] != null && todo['time'].toString().isNotEmpty) {
                timeInfo = " (${todo['time']})";
              }
              responseMsg += "• $completedMark${todo['title']}$timeInfo\n";
            }

            final completionRate = todayTodos.isEmpty ? 0 : (completedCount / todayTodos.length * 100).round();
            responseMsg += "\n현재 완료율: $completionRate%";
          }
        }
      } else {
        responseMsg = "현재 오프라인 모드에서는 상세한 일정 정보를 제공할 수 없습니다. 인터넷 연결을 확인해주세요.";
      }

      response["response"] = responseMsg;
    }
    else if (message.contains("추천") || message.contains("빈 시간")) {
      response["response"] = "오늘 남은 시간에 할 만한 활동으로 독서, 운동, 또는 계획 세우기를 추천드립니다. (오프라인 모드)";
    }
    else if (message.contains("도움말") || message.contains("어떻게") || message.contains("사용")) {
      response["response"] = "저는 일정 관리와 시간 계획을 도와드리는 AI 비서입니다. 일정 추가, 삭제, 추천 등의 기능을 사용해보세요. (오프라인 모드)";
    }

    return response;
  }

  String _padZero(int num) {
    return num.toString().padLeft(2, '0');
  }
}