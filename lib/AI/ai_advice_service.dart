import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIAdviceService {
// 대신 가능한 URL 목록 정의:
  static const List<String> possibleUrls = [
    'https://railwavve-production-68d4.up.railway.app',       // 안드로이드 에뮬레이터
    'https://railwavve-production-68d4.up.railway.app/', // 서버 실제 IP (로컬 네트워크)
    'https://railwavve-production-68d4.up.railway.app/',      // 로컬호스트
    'https://railwavve-production-68d4.up.railway.app/'       // 로컬호스트 (이름)
  ];

// API 엔드포인트 접미사 정의
  static const String geminiEndpointPath = "/gemini";

  static String _apiKey = 'AIzaSyB3Gx-qcHLpyBNsuH4UQ-JKRSDeisoo5-c';
  static String get _apiUrl => 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';

// getGeminiUrl() 헬퍼 메서드 추가
  static String getGeminiEndpoint(String baseUrl) {
    return "$baseUrl$geminiEndpointPath";
  }

  // 디버깅용 - 데이터 출력
  static void _printDebugData(String endpoint, Map<String, dynamic> data) {
    print('===== 요청 정보 (${endpoint}) =====');
    print('데이터: ${jsonEncode(data)}');
  }

  // 사용자 닉네임 가져오기 함수
  static Future<String> getUserNickname() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('nickname') ?? '사용자';
    } catch (e) {
      print('닉네임 로드 오류: $e');
      return '사용자';
    }
  }
  // 추천 옵션 카테고리 생성
  static List<Map<String, dynamic>> generateRecommendationOptions(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {

    // 기본 빠른 액션 옵션
    final options = [
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

    // 사용자 일정과 할 일에서 키워드 검색
    bool hasStudyTask = false;
    bool hasTravelPlan = false;
    bool hasWorkoutPlan = false;
    bool hasExam = false;
    String travelDestination = "";

    // 할 일에서 키워드 확인
    for (var task in tasks) {
      final title = task['title'].toString().toLowerCase();

      if (title.contains('공부') || title.contains('학습') || title.contains('study') ||
          title.contains('과제') || title.contains('숙제')) {
        hasStudyTask = true;
      }

      if (title.contains('모의고사') || title.contains('시험') ||
          title.contains('exam') || title.contains('test')) {
        hasExam = true;
      }

      if (title.contains('운동') || title.contains('workout') ||
          title.contains('헬스') || title.contains('exercise')) {
        hasWorkoutPlan = true;
      }
    }

    // 일정에서 키워드 확인
    for (var event in calendar) {
      final title = event['title'].toString().toLowerCase();

      // 여행 관련 키워드 확인 및 목적지 추출
      if (title.contains('여행') || title.contains('trip') || title.contains('vacation')) {
        hasTravelPlan = true;

        // 여행지 추출 시도
        final List<String> destinations = ['일본', '미국', '유럽', '제주', '부산', '서울', '대만', '홍콩', '호주'];
        for (var dest in destinations) {
          if (title.contains(dest.toLowerCase())) {
            travelDestination = dest;
            break;
          }
        }
      }
    }

    // 사용자 맞춤 옵션 추가
    if (hasStudyTask) {
      options.add({
        "text": "공부 계획 세우기",
        "action": "study_plan",
        "icon": "book"
      });
    }

    if (hasExam) {
      options.add({
        "text": "모의고사 대비 계획",
        "action": "exam_prep",
        "icon": "school"
      });
    }

    if (hasTravelPlan) {
      options.add({
        "text": travelDestination.isNotEmpty ?
        "$travelDestination 여행 준비물" : "여행 준비 체크리스트",
        "action": "travel_checklist",
        "icon": "flight"
      });
    }

    if (hasWorkoutPlan) {
      options.add({
        "text": "운동 루틴 추천",
        "action": "workout_routine",
        "icon": "fitness"
      });
    }

    return options;
  }

  Map<String, dynamic> generateOfflineResponse(String message) {
    // 캘린더 및 할 일 목록이 없는 경우를 대비한 빈 리스트
    final List<Map<String, dynamic>> emptyCalendar = [];
    final List<Map<String, dynamic>> emptyTasks = [];

    return _getFallbackResponse(message, emptyCalendar, emptyTasks);
  }

  // 숫자 패딩 헬퍼 메서드 추가
  static String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }

  // 챗봇에서의 일정 추가/삭제 요청 처리 개선
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
    String? action,
  }) async {
    try {
      // API 키 확인
      if (_apiKey.isEmpty) {
        return generateOfflineResponse(message);
      }

      // 일정 추가/삭제 요청 분석
      final bool isAddRequest = _isAddEventRequest(message);
      final bool isDeleteRequest = _isDeleteEventRequest(message);

      // 현재 날짜 및 시간
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 일정 추가/삭제 요청인 경우, 적절한 액션 생성
      if (isAddRequest) {
        final extractedData = _extractEventData(message);
        if (extractedData != null) {
          return {
            "response": "네, '${extractedData['title']}' 일정을 ${extractedData['date'] ?? '오늘'} ${extractedData['time'] ?? ''} 추가할게요.",
            "actions": [
              {
                "action": "add_task",
                "data": extractedData
              }
            ]
          };
        }
      } else if (isDeleteRequest) {
        final eventTitle = _extractEventTitle(message);
        if (eventTitle != null && eventTitle.isNotEmpty) {
          return {
            "response": "'$eventTitle' 일정을 삭제할게요. 확인해주세요.",
            "actions": [
              {
                "action": "delete_task",
                "data": {
                  "title": eventTitle
                }
              }
            ]
          };
        }
      }

      // 일정/할일 조회 요청 처리
      if (_isTodayScheduleRequest(message)) {
        return _generateTodayScheduleResponse(calendar, tasks);
      }

      // 시간 추천 요청 처리
      if (_isTimeRecommendationRequest(message)) {
        return await _generateTimeRecommendationResponse(calendar, tasks);
      }

      // 대화 기록 형식화 - user와 model 역할만 사용
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
- add_recommended_task: 추천 일정 추가 (필수 필드: index)

사용자가 "오늘 할 일"이나 "내 일정" 등을 물으면 구체적으로 답변하고, 절대 스스로 생각해보라고 하지 마세요.
항상 친절하고 도움이 되도록 대화하며, 한국어로 응답하세요.
''';

      // 대화 설정
      List<Map<String, dynamic>> conversationContents = [];

      // 비어있지 않은 대화 기록이 있는 경우에만 기존 대화 추가
      if (formattedHistory.isNotEmpty) {
        conversationContents.addAll(formattedHistory);
      } else {
        // 첫 대화면 초기 설명 추가
        conversationContents.add({
          "role": "user",
          "parts": [{"text": "안녕하세요. 도움이 필요합니다."}]
        });

        conversationContents.add({
          "role": "model",
          "parts": [{"text": initialPrompt}]
        });
      }

      // 사용자 메시지 추가
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

      // API 요청 보내기 (타임아웃 설정)
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        // JSON 부분 추출 및 파싱
        try {
          // JSON 부분만 추출
          final jsonStart = text.indexOf('{');
          final jsonEnd = text.lastIndexOf('}') + 1;

          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonString = text.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> parsedResponse = Map<String, dynamic>.from(json.decode(jsonString));

            // 액션 필드가 없으면 빈 배열 추가
            if (!parsedResponse.containsKey('actions')) {
              parsedResponse['actions'] = <Map<String, dynamic>>[];
            } else {
              // actions가 있으면 형식 확인 및 변환
              final actions = parsedResponse['actions'];
              if (actions is List) {
                parsedResponse['actions'] = List<Map<String, dynamic>>.from(
                    actions.map((action) => Map<String, dynamic>.from(action))
                );
              }
            }

            return parsedResponse;
          } else {
            // JSON이 없는 경우 텍스트만 반환
            return {
              "response": text,
              "actions": <Map<String, dynamic>>[]
            };
          }
        } catch (e) {
          print('JSON 파싱 오류: $e');
          print('원본 텍스트: $text');

          // 파싱 오류 시 텍스트만 반환
          return {
            "response": text,
            "actions": <Map<String, dynamic>>[]
          };
        }
      }

      print('API 응답 오류: ${response.statusCode}, ${response.body}');
      throw Exception('API 요청 실패: ${response.statusCode}');
    } catch (e) {
      print('AI 응답 처리 중 오류: $e');
      return generateOfflineResponse(message);
    }
  }

// 오늘의 일정/할일 요청인지 확인하는 함수
  bool _isTodayScheduleRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('오늘 일정') ||
        lowerMessage.contains('오늘의 일정') ||
        lowerMessage.contains('오늘 할 일') ||
        lowerMessage.contains('오늘의 할 일') ||
        lowerMessage.contains('오늘 뭐해') ||
        lowerMessage.contains('오늘 뭐 해야') ||
        lowerMessage.contains('오늘 해야 할 일') ||
        (lowerMessage.contains('내 일정') && lowerMessage.contains('알려'));
  }

// 시간 추천 요청인지 확인하는 함수
  bool _isTimeRecommendationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('시간 추천') ||
        lowerMessage.contains('언제가 좋을까') ||
        lowerMessage.contains('추천 일정') ||
        lowerMessage.contains('뭐 하면 좋을까') ||
        lowerMessage.contains('시간표 짜');
  }

// 일정 추가 요청인지 확인하는 함수
  bool _isAddEventRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return (lowerMessage.contains('일정') || lowerMessage.contains('할 일') || lowerMessage.contains('이벤트') || lowerMessage.contains('약속')) &&
        (lowerMessage.contains('추가') || lowerMessage.contains('만들') || lowerMessage.contains('저장') || lowerMessage.contains('등록') || lowerMessage.contains('넣어'));
  }

// 일정 삭제 요청인지 확인하는 함수
  bool _isDeleteEventRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return (lowerMessage.contains('일정') || lowerMessage.contains('할 일') || lowerMessage.contains('이벤트') || lowerMessage.contains('약속')) &&
        (lowerMessage.contains('삭제') || lowerMessage.contains('지워') || lowerMessage.contains('취소') || lowerMessage.contains('제거') || lowerMessage.contains('없애'));
  }

// 메시지에서 일정 제목 추출하는 함수
  String? _extractEventTitle(String message) {
    // 메시지에서 일정 제목 추출 시도
    // "OOO 일정을 삭제해줘" 패턴
    final titleBeforePattern = RegExp(r'([가-힣a-zA-Z0-9\s]+)\s*(일정|할 일|이벤트|약속).*?(?:삭제|지워|취소|제거|없애)');
    final titleBeforeMatch = titleBeforePattern.firstMatch(message);

    if (titleBeforeMatch != null && titleBeforeMatch.group(1) != null) {
      return titleBeforeMatch.group(1)!.trim();
    }

    // "OOO 삭제해줘" 패턴
    final simplePattern = RegExp(r'([가-힣a-zA-Z0-9\s]+)(?:삭제|지워|취소|제거|없애)');
    final simpleMatch = simplePattern.firstMatch(message);

    if (simpleMatch != null && simpleMatch.group(1) != null) {
      return simpleMatch.group(1)!.trim();
    }

    // "일정 삭제해줘 OOO" 패턴
    final titleAfterPattern = RegExp(r'(?:일정|할 일|이벤트|약속).*?(?:삭제|지워|취소|제거|없애).*?(?:해|해줘|해주세요|할래).*?([가-힣a-zA-Z0-9\s]+)');
    final titleAfterMatch = titleAfterPattern.firstMatch(message);

    if (titleAfterMatch != null && titleAfterMatch.group(1) != null) {
      return titleAfterMatch.group(1)!.trim();
    }

    return null;
  }

// 메시지에서 일정 데이터 추출하는 함수
  Map<String, dynamic>? _extractEventData(String message) {
    final Map<String, dynamic> eventData = {
      'title': '',
      'date': DateTime.now().toString().split(' ')[0], // 기본값: 오늘
      'time': null,
      'endTime': null,
      'description': '',
      'location': '',
    };

    // 제목 추출
    final titlePattern = RegExp(r'(?:제목[은는이가]?\s*[:\s]\s*)?([가-힣a-zA-Z0-9\s]+)(?:일정|할 일)?(?:을|를)?\s*(?:추가|만들|저장|등록)');
    final titleMatch = titlePattern.firstMatch(message);

    if (titleMatch != null && titleMatch.group(1) != null) {
      eventData['title'] = titleMatch.group(1)!.trim();
    } else {
      // 제목이 없으면 기본 추출 시도
      final words = message.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (words[i].contains('일정') || words[i].contains('할') && i > 0) {
          eventData['title'] = words[i-1];
          break;
        }
      }
    }

    // 날짜 추출
    final datePatterns = [
      RegExp(r'(\d{4}년\s*\d{1,2}월\s*\d{1,2}일)'), // YYYY년 MM월 DD일
      RegExp(r'(\d{1,2}월\s*\d{1,2}일)'),          // MM월 DD일
      RegExp(r'(\d{4}-\d{2}-\d{2})'),             // YYYY-MM-DD
      RegExp(r'(\d{4}/\d{2}/\d{2})'),             // YYYY/MM/DD
      RegExp(r'(오늘|내일|모레)'),                   // 상대적 날짜
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null && match.group(1) != null) {
        final dateStr = match.group(1)!;

        if (dateStr == '오늘') {
          final now = DateTime.now();
          eventData['date'] = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        } else if (dateStr == '내일') {
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          eventData['date'] = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
        } else if (dateStr == '모레') {
          final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));
          eventData['date'] = "${dayAfterTomorrow.year}-${dayAfterTomorrow.month.toString().padLeft(2, '0')}-${dayAfterTomorrow.day.toString().padLeft(2, '0')}";
        } else if (dateStr.contains('년') && dateStr.contains('월') && dateStr.contains('일')) {
          // YYYY년 MM월 DD일 형식 처리
          final yearMatch = RegExp(r'(\d{4})년').firstMatch(dateStr);
          final monthMatch = RegExp(r'(\d{1,2})월').firstMatch(dateStr);
          final dayMatch = RegExp(r'(\d{1,2})일').firstMatch(dateStr);

          if (yearMatch != null && monthMatch != null && dayMatch != null) {
            final year = int.parse(yearMatch.group(1)!);
            final month = int.parse(monthMatch.group(1)!);
            final day = int.parse(dayMatch.group(1)!);
            eventData['date'] = "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
          }
        } else if (dateStr.contains('월') && dateStr.contains('일')) {
          // MM월 DD일 형식 처리 (현재 연도 사용)
          final monthMatch = RegExp(r'(\d{1,2})월').firstMatch(dateStr);
          final dayMatch = RegExp(r'(\d{1,2})일').firstMatch(dateStr);

          if (monthMatch != null && dayMatch != null) {
            final year = DateTime.now().year;
            final month = int.parse(monthMatch.group(1)!);
            final day = int.parse(dayMatch.group(1)!);
            eventData['date'] = "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
          }
        } else if (dateStr.contains('-')) {
          // YYYY-MM-DD 형식 그대로 사용
          eventData['date'] = dateStr;
        } else if (dateStr.contains('/')) {
          // YYYY/MM/DD 형식을 YYYY-MM-DD로 변환
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            eventData['date'] = "${parts[0]}-${parts[1]}-${parts[2]}";
          }
        }

        break;
      }
    }

    // 시간 추출
    final timePatterns = [
      RegExp(r'(\d{1,2})시\s*(\d{1,2})분'),      // HH시 MM분
      RegExp(r'(\d{1,2})시'),                    // HH시
      RegExp(r'(\d{1,2}):(\d{2})'),             // HH:MM
      RegExp(r'(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})?분?'), // 오전/오후 HH시 MM분
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        if (pattern.pattern == r'(\d{1,2})시\s*(\d{1,2})분') {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          eventData['time'] = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        } else if (pattern.pattern == r'(\d{1,2})시') {
          final hour = int.parse(match.group(1)!);
          eventData['time'] = "${hour.toString().padLeft(2, '0')}:00";
        } else if (pattern.pattern == r'(\d{1,2}):(\d{2})') {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          eventData['time'] = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        } else if (pattern.pattern == r'(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})?분?') {
          final ampm = match.group(1);
          final hour = int.parse(match.group(2)!);
          final minute = match.group(3) != null ? int.parse(match.group(3)!) : 0;

          int formattedHour = hour;
          if (ampm == '오후' && hour < 12) {
            formattedHour += 12;
          } else if (ampm == '오전' && hour == 12) {
            formattedHour = 0;
          }

          eventData['time'] = "${formattedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        }

        break;
      }
    }

    // 종료 시간 추출
    final endTimePatterns = [
      RegExp(r'~\s*(\d{1,2})시\s*(\d{1,2})분'),     // ~ HH시 MM분
      RegExp(r'~\s*(\d{1,2})시'),                   // ~ HH시
      RegExp(r'~\s*(\d{1,2}):(\d{2})'),            // ~ HH:MM
      RegExp(r'~\s*(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})?분?'), // ~ 오전/오후 HH시 MM분
    ];

    for (final pattern in endTimePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        if (pattern.pattern == r'~\s*(\d{1,2})시\s*(\d{1,2})분') {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          eventData['endTime'] = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        } else if (pattern.pattern == r'~\s*(\d{1,2})시') {
          final hour = int.parse(match.group(1)!);
          eventData['endTime'] = "${hour.toString().padLeft(2, '0')}:00";
        } else if (pattern.pattern == r'~\s*(\d{1,2}):(\d{2})') {
          final hour = int.parse(match.group(1)!);
          final minute = int.parse(match.group(2)!);
          eventData['endTime'] = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        } else if (pattern.pattern == r'~\s*(오전|오후)\s*(\d{1,2})시\s*(\d{1,2})?분?') {
          final ampm = match.group(1);
          final hour = int.parse(match.group(2)!);
          final minute = match.group(3) != null ? int.parse(match.group(3)!) : 0;

          int formattedHour = hour;
          if (ampm == '오후' && hour < 12) {
            formattedHour += 12;
          } else if (ampm == '오전' && hour == 12) {
            formattedHour = 0;
          }

          eventData['endTime'] = "${formattedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        }

        break;
      }
    }

    // 종료 시간이 없고 시작 시간이 있으면 기본적으로 1시간 지속으로 설정
    if (eventData['time'] != null && eventData['endTime'] == null) {
      final timeStr = eventData['time'] as String;
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final endHour = (hour + 1) % 24;
        eventData['endTime'] = "${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      }
    }

    // 위치 추출
    final locationPattern = RegExp(r'장소[는은]?\s*([가-힣a-zA-Z0-9\s]+)');
    final locationMatch = locationPattern.firstMatch(message);

    if (locationMatch != null && locationMatch.group(1) != null) {
      eventData['location'] = locationMatch.group(1)!.trim();
    }

    // 설명 추출
    final descriptionPattern = RegExp(r'설명[은는]?\s*([가-힣a-zA-Z0-9\s]+)');
    final descriptionMatch = descriptionPattern.firstMatch(message);

    if (descriptionMatch != null && descriptionMatch.group(1) != null) {
      eventData['description'] = descriptionMatch.group(1)!.trim();
    }

    // 제목이 없으면 null 반환 (필수 필드)
    if (eventData['title'] == null || eventData['title'].toString().isEmpty) {
      return null;
    }

    return eventData;
  }

  // 일정 분석 및 추천 요청 처리
  static Future<Map<String, dynamic>> analyzeScheduleAndRecommend({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
  }) async {
    try {
      final now = DateTime.now();
      final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 오늘 일정 분석
      final todayEvents = calendar.where((event) {
        return event['date'] == today || (event['date'] != null && event['date'].startsWith(today));
      }).toList();

      final todayTasks = tasks.where((task) {
        return task['date'] == today || (task['date'] != null && task['date'].startsWith(today));
      }).toList();

      // 분석 단계별 진행
      if (message.contains('일정 분석') || message.contains('분석')) {
        return _generateScheduleAnalysis(todayEvents, todayTasks);
      } else if (message.contains('추천') || message.contains('뭐 해야')) {
        return _generateScheduleRecommendation(todayEvents, todayTasks);
      }

      return {
        "response": "일정 분석과 추천을 도와드릴게요. 어떤 것을 원하시나요?",
        "actions": []
      };
    } catch (e) {
      print('일정 분석 오류: $e');
      return {
        "response": "일정 분석 중 오류가 발생했습니다.",
        "actions": []
      };
    }
  }

// 일정 분석 결과 생성
  static Map<String, dynamic> _generateScheduleAnalysis(
      List<Map<String, dynamic>> todayEvents,
      List<Map<String, dynamic>> todayTasks
      ) {
    String analysis = "📊 **오늘 일정 분석 결과**\n\n";

    // 시간 분석
    analysis += "⏰ **시간 현황:**\n";
    int busyHours = 0;
    int freeHours = 24;

    for (var event in todayEvents) {
      if (event['startTime'] != null && event['endTime'] != null) {
        // 대략적인 시간 계산
        busyHours += 1;
      }
    }

    freeHours -= busyHours;
    analysis += "• 예정된 일정: ${todayEvents.length}개\n";
    analysis += "• 예상 소요시간: 약 ${busyHours}시간\n";
    analysis += "• 여유시간: 약 ${freeHours}시간\n\n";

    // 할 일 분석
    final completedTasks = todayTasks.where((task) => task['isCompleted'] == true).length;
    final totalTasks = todayTasks.length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

    analysis += "📝 **할 일 현황:**\n";
    analysis += "• 총 할 일: ${totalTasks}개\n";
    analysis += "• 완료: ${completedTasks}개\n";
    analysis += "• 완료율: ${completionRate}%\n\n";

    // 우선순위 분석
    final importantTasks = todayTasks.where((task) =>
    task['importance'] != null &&
        int.tryParse(task['importance'].toString()) != null &&
        int.parse(task['importance'].toString()) >= 4
    ).toList();

    analysis += "🔥 **우선순위 높은 할 일:**\n";
    if (importantTasks.isNotEmpty) {
      for (var task in importantTasks.take(3)) {
        analysis += "• ${task['title']}\n";
      }
    } else {
      analysis += "• 긴급한 할 일은 없어요!\n";
    }

    analysis += "\n💡 **오늘 하루를 더 효율적으로 보내고 싶으시다면 '추천 일정 만들어줘'라고 말씀해주세요!**";

    return {
      "response": analysis,
      "actions": [
        {
          "action": "analyze_complete",
          "data": {
            "totalEvents": todayEvents.length,
            "totalTasks": totalTasks,
            "completionRate": completionRate,
            "importantTasks": importantTasks.length
          }
        }
      ]
    };
  }

// 개인 맞춤 일정 추천 생성
  static Map<String, dynamic> _generateScheduleRecommendation(
      List<Map<String, dynamic>> todayEvents,
      List<Map<String, dynamic>> todayTasks
      ) {
    String recommendation = "🎯 **맞춤 일정 추천**\n\n";
    recommendation += "현재 일정을 분석해서 최적의 하루 계획을 만들어드릴게요!\n\n";

    // 질문 단계 시작
    recommendation += "📋 **몇 가지 질문에 답해주시면 더 정확한 추천을 드릴 수 있어요:**\n\n";
    recommendation += "1. 오늘 가장 집중하고 싶은 활동은 무엇인가요?\n";
    recommendation += "   (예: 공부, 운동, 휴식, 취미활동)\n\n";
    recommendation += "2. 선호하는 활동 시간대는 언제인가요?\n";
    recommendation += "   (예: 오전, 오후, 저녁)\n\n";
    recommendation += "3. 하루에 얼마나 많은 활동을 원하시나요?\n";
    recommendation += "   (예: 여유롭게, 보통, 빡빡하게)\n\n";

    recommendation += "💬 **답변 예시:** '공부에 집중하고 싶고, 오전에 활동하는 걸 좋아해요. 여유롭게 하고 싶어요!'";

    return {
      "response": recommendation,
      "actions": [
        {
          "action": "start_recommendation_questions",
          "data": {
            "step": 1,
            "totalSteps": 3
          }
        }
      ],
      "expectingUserInput": true
    };
  }

// 사용자 응답 기반 맞춤 일정 생성
  static Future<Map<String, dynamic>> createPersonalizedSchedule({
    required String userPreferences,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 사용자 선호도 분석
    Map<String, dynamic> preferences = _parseUserPreferences(userPreferences);

    // 빈 시간대 찾기
    List<String> freeTimeSlots = _findAvailableTimeSlots(calendar, today);

    // 추천 일정 생성
    List<Map<String, dynamic>> recommendedSchedule = _generateRecommendedActivities(
        preferences,
        freeTimeSlots,
        tasks
    );

    String response = "🌟 **맞춤 일정이 완성되었어요!**\n\n";
    response += "당신의 선호도를 바탕으로 오늘 하루 일정을 만들어봤어요:\n\n";

    for (int i = 0; i < recommendedSchedule.length; i++) {
      final activity = recommendedSchedule[i];
      response += "${i + 1}. **${activity['time']}** - ${activity['title']}\n";
      response += "   ${activity['description']}\n\n";
    }

    response += "🤔 **이 일정들을 오늘 플래너에 추가하시겠어요?**\n";
    response += "'네' 또는 '추가해줘'라고 답하시면 자동으로 플래너에 추가해드릴게요!";

    return {
      "response": response,
      "actions": [
        {
          "action": "show_recommended_schedule",
          "data": {
            "schedule": recommendedSchedule,
            "date": today
          }
        }
      ],
      "recommendedSchedule": recommendedSchedule
    };
  }

// 사용자 선호도 파싱
  static Map<String, dynamic> _parseUserPreferences(String userInput) {
    final lowerInput = userInput.toLowerCase();

    // 활동 유형 파악
    String preferredActivity = 'general';
    if (lowerInput.contains('공부') || lowerInput.contains('학습')) {
      preferredActivity = 'study';
    } else if (lowerInput.contains('운동') || lowerInput.contains('헬스')) {
      preferredActivity = 'exercise';
    } else if (lowerInput.contains('휴식') || lowerInput.contains('쉬')) {
      preferredActivity = 'rest';
    } else if (lowerInput.contains('취미') || lowerInput.contains('여가')) {
      preferredActivity = 'hobby';
    }

    // 시간대 선호도
    String preferredTime = 'all';
    if (lowerInput.contains('오전')) {
      preferredTime = 'morning';
    } else if (lowerInput.contains('오후')) {
      preferredTime = 'afternoon';
    } else if (lowerInput.contains('저녁')) {
      preferredTime = 'evening';
    }

    // 강도 선호도
    String intensity = 'normal';
    if (lowerInput.contains('여유') || lowerInput.contains('천천히')) {
      intensity = 'light';
    } else if (lowerInput.contains('빡빡') || lowerInput.contains('많이')) {
      intensity = 'intense';
    }

    return {
      'activity': preferredActivity,
      'time': preferredTime,
      'intensity': intensity
    };
  }

// 빈 시간대 찾기
  static List<String> _findAvailableTimeSlots(List<Map<String, dynamic>> calendar, String date) {
    final busySlots = <String>[];

    // 기존 일정의 시간대 수집
    final todayEvents = calendar.where((event) =>
    event['date'] == date || (event['date'] != null && event['date'].startsWith(date))
    ).toList();

    for (var event in todayEvents) {
      if (event['startTime'] != null) {
        if (event['startTime'] is Map) {
          final hour = event['startTime']['hour'] ?? 0;
          busySlots.add('${hour.toString().padLeft(2, '0')}:00');
        } else if (event['startTime'] is String) {
          busySlots.add(event['startTime'].toString());
        }
      }
    }

    // 9시부터 21시까지 1시간 단위로 빈 시간 찾기
    final allSlots = <String>[];
    for (int hour = 9; hour <= 20; hour++) {
      final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
      if (!busySlots.contains(timeSlot)) {
        allSlots.add(timeSlot);
      }
    }

    return allSlots;
  }

// 추천 활동 생성
  static List<Map<String, dynamic>> _generateRecommendedActivities(
      Map<String, dynamic> preferences,
      List<String> freeTimeSlots,
      List<Map<String, dynamic>> tasks
      ) {
    final recommendedActivities = <Map<String, dynamic>>[];

    if (freeTimeSlots.isEmpty) return recommendedActivities;

    final activityType = preferences['activity'];
    final timePreference = preferences['time'];
    final intensity = preferences['intensity'];

    // 시간대별 필터링
    List<String> filteredSlots = freeTimeSlots;
    if (timePreference != 'all') {
      filteredSlots = freeTimeSlots.where((slot) {
        final hour = int.parse(slot.split(':')[0]);
        switch (timePreference) {
          case 'morning':
            return hour >= 9 && hour < 12;
          case 'afternoon':
            return hour >= 12 && hour < 18;
          case 'evening':
            return hour >= 18 && hour <= 20;
          default:
            return true;
        }
      }).toList();
    }

    // 활동 수 결정
    int maxActivities;
    switch (intensity) {
      case 'light':
        maxActivities = 2;
        break;
      case 'intense':
        maxActivities = min(5, filteredSlots.length);
        break;
      default:
        maxActivities = min(3, filteredSlots.length);
    }

    // 활동 유형별 추천
    final activities = _getActivityTemplates(activityType);

    for (int i = 0; i < maxActivities && i < filteredSlots.length; i++) {
      final activity = activities[i % activities.length];
      final endHour = int.parse(filteredSlots[i].split(':')[0]) + 1;

      recommendedActivities.add({
        'title': activity['title'],
        'description': activity['description'],
        'time': filteredSlots[i],
        'endTime': '${endHour.toString().padLeft(2, '0')}:00',
        'type': activityType,
        'importance': activity['importance'] ?? 3,
        'urgency': activity['urgency'] ?? 3,
      });
    }

    return recommendedActivities;
  }

  // 일정 검색 및 삭제 관련 함수들
  static Map<String, dynamic> searchAndDeleteSchedule({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) {
    final lowerMessage = message.toLowerCase();

    // 삭제 키워드 확인
    if (!lowerMessage.contains('삭제') && !lowerMessage.contains('지워') &&
        !lowerMessage.contains('취소') && !lowerMessage.contains('제거')) {
      return {
        "response": "삭제하고 싶은 일정을 알려주세요. 예: '팀 회의 삭제해줘'",
        "actions": []
      };
    }

    // 검색어 추출
    String searchKeyword = _extractDeleteKeyword(message);

    if (searchKeyword.isEmpty) {
      // 전체 일정 보기
      return _showAllSchedulesForDeletion(calendar, tasks);
    }

    // 키워드로 일정 검색
    Map<String, dynamic> searchResults = _searchSchedulesByKeyword(searchKeyword, calendar, tasks);

    if (searchResults['total'] == 0) {
      return {
        "response": "'$searchKeyword'와 관련된 일정을 찾을 수 없어요. 다른 키워드로 검색해보세요.",
        "actions": []
      };
    } else if (searchResults['total'] == 1) {
      // 1개 발견 시 즉시 삭제 확인
      return _confirmSingleDeletion(searchResults);
    } else {
      // 여러 개 발견 시 선택 요청
      return _showMultipleOptionsForDeletion(searchResults);
    }
  }

// 삭제 키워드 추출
  static String _extractDeleteKeyword(String message) {
    // "팀 회의 삭제해줘" -> "팀 회의"
    // "회의 지워줘" -> "회의"

    final deleteWords = ['삭제해줘', '삭제해', '삭제', '지워줘', '지워', '취소해줘', '취소', '제거해줘', '제거', '없애줘', '없애'];

    for (String deleteWord in deleteWords) {
      if (message.contains(deleteWord)) {
        // 삭제 키워드 앞의 단어들 추출
        int index = message.indexOf(deleteWord);
        String beforeDelete = message.substring(0, index).trim();

        // 불필요한 단어 제거
        final unnecessaryWords = ['일정', '할일', '할 일', '을', '를', '이', '가', '의', '에', '그', '그거', '저거'];
        for (String word in unnecessaryWords) {
          beforeDelete = beforeDelete.replaceAll(word, '').trim();
        }

        return beforeDelete;
      }
    }

    return '';
  }

// 전체 일정 보기 (삭제용)
  static Map<String, dynamic> _showAllSchedulesForDeletion(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    String response = "📋 **삭제 가능한 일정 목록:**\n\n";
    List<Map<String, dynamic>> allItems = [];

    // 캘린더 일정 추가
    for (int i = 0; i < calendar.length; i++) {
      final event = calendar[i];
      allItems.add({
        'type': 'calendar',
        'index': i,
        'id': event['id'],
        'title': event['title'],
        'date': event['date'],
        'data': event
      });

      response += "${allItems.length}. 📅 캘린더: '${event['title']}' (${event['date']})\n";
    }

    // 투두리스트 추가
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      allItems.add({
        'type': 'todo',
        'index': i,
        'id': task['id'],
        'title': task['title'],
        'date': task['date'],
        'data': task
      });

      response += "${allItems.length}. 📝 투두: '${task['title']}' (${task['date'] ?? '날짜 없음'})\n";
    }

    if (allItems.isEmpty) {
      response = "삭제할 수 있는 일정이 없어요.";
      return {
        "response": response,
        "actions": []
      };
    }

    response += "\n번호를 선택하거나 제목을 말씀해주세요!";

    return {
      "response": response,
      "actions": [
        {
          "action": "show_deletion_list",
          "data": {
            "items": allItems
          }
        }
      ]
    };
  }

// 키워드로 일정 검색
  static Map<String, dynamic> _searchSchedulesByKeyword(
      String keyword,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    List<Map<String, dynamic>> foundItems = [];

    // 캘린더에서 검색
    for (int i = 0; i < calendar.length; i++) {
      final event = calendar[i];
      if (event['title'] != null &&
          event['title'].toString().toLowerCase().contains(keyword.toLowerCase())) {
        foundItems.add({
          'type': 'calendar',
          'index': i,
          'id': event['id'],
          'title': event['title'],
          'date': event['date'],
          'data': event
        });
      }
    }

    // 투두리스트에서 검색
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task['title'] != null &&
          task['title'].toString().toLowerCase().contains(keyword.toLowerCase())) {
        foundItems.add({
          'type': 'todo',
          'index': i,
          'id': task['id'],
          'title': task['title'],
          'date': task['date'],
          'data': task
        });
      }
    }

    return {
      'keyword': keyword,
      'total': foundItems.length,
      'items': foundItems
    };
  }

// 단일 항목 삭제 확인
  static Map<String, dynamic> _confirmSingleDeletion(Map<String, dynamic> searchResults) {
    final item = searchResults['items'][0];
    final type = item['type'] == 'calendar' ? '캘린더' : '투두리스트';
    final emoji = item['type'] == 'calendar' ? '📅' : '📝';

    String response = "🗑️ **삭제 확인**\n\n";
    response += "다음 일정을 삭제하시겠어요?\n";
    response += "$emoji $type: '${item['title']}' (${item['date'] ?? '날짜 없음'})\n\n";
    response += "'네' 또는 '삭제'라고 답하시면 삭제됩니다.";

    return {
      "response": response,
      "actions": [
        {
          "action": "confirm_single_deletion",
          "data": item
        }
      ]
    };
  }

// 다중 항목 선택 요청
  static Map<String, dynamic> _showMultipleOptionsForDeletion(Map<String, dynamic> searchResults) {
    final keyword = searchResults['keyword'];
    final items = searchResults['items'] as List<Map<String, dynamic>>;

    String response = "🔍 **'$keyword'와 관련된 일정이 ${items.length}개 있어요:**\n\n";

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final type = item['type'] == 'calendar' ? '캘린더' : '투두리스트';
      final emoji = item['type'] == 'calendar' ? '📅' : '📝';

      response += "${i + 1}. $emoji $type: '${item['title']}' (${item['date'] ?? '날짜 없음'})\n";
    }

    response += "\n어떤 것을 삭제하시겠어요? 번호로 선택해주세요!";

    return {
      "response": response,
      "actions": [
        {
          "action": "show_multiple_deletion_options",
          "data": {
            "items": items,
            "keyword": keyword
          }
        }
      ]
    };
  }

// 활동 유형별 템플릿
  static List<Map<String, dynamic>> _getActivityTemplates(String activityType) {
    switch (activityType) {
      case 'study':
        return [
          {
            'title': '집중 공부 시간',
            'description': '가장 중요한 학습 내용에 집중하는 시간',
            'importance': 4,
            'urgency': 4,
          },
          {
            'title': '복습 및 정리',
            'description': '배운 내용을 정리하고 복습하는 시간',
            'importance': 3,
            'urgency': 3,
          },
          {
            'title': '문제 풀이',
            'description': '연습 문제를 풀어보며 실력을 향상시키는 시간',
            'importance': 4,
            'urgency': 3,
          },
        ];
      case 'exercise':
        return [
          {
            'title': '유산소 운동',
            'description': '건강한 몸을 위한 유산소 운동 시간',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '근력 운동',
            'description': '근력 향상을 위한 웨이트 트레이닝',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '스트레칭',
            'description': '몸의 긴장을 풀어주는 스트레칭 시간',
            'importance': 2,
            'urgency': 2,
          },
        ];
      case 'rest':
        return [
          {
            'title': '명상 및 휴식',
            'description': '마음의 평안을 찾는 명상 시간',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '여유로운 산책',
            'description': '자연을 느끼며 걷는 힐링 시간',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '음악 감상',
            'description': '좋아하는 음악을 들으며 휴식하는 시간',
            'importance': 1,
            'urgency': 1,
          },
        ];
      case 'hobby':
        return [
          {
            'title': '취미 활동',
            'description': '좋아하는 취미를 즐기는 시간',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '독서 시간',
            'description': '책을 읽으며 지식을 쌓는 시간',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '영화/드라마 감상',
            'description': '재미있는 영상 콘텐츠를 즐기는 시간',
            'importance': 1,
            'urgency': 1,
          },
        ];
      default:
        return [
          {
            'title': '계획 세우기',
            'description': '앞으로의 일정을 계획하고 정리하는 시간',
            'importance': 3,
            'urgency': 3,
          },
          {
            'title': '정리 정돈',
            'description': '주변 환경을 깔끔하게 정리하는 시간',
            'importance': 2,
            'urgency': 2,
          },
          {
            'title': '자기계발',
            'description': '새로운 것을 배우고 성장하는 시간',
            'importance': 3,
            'urgency': 2,
          },
        ];
    }
  }


// 오늘 일정 요약 응답 생성
  Map<String, dynamic> _generateTodayScheduleResponse(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 일정 필터링
    final todayEvents = calendar.where((event) {
      return event['date'] == today || (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    // 오늘 할 일 필터링
    final todayTasks = tasks.where((task) {
      return task['date'] == today || (task['date'] != null && task['date'].startsWith(today));
    }).toList();

    // 응답 생성
    String response = "오늘 일정을 알려드릴게요.\n\n";

    if (todayEvents.isEmpty && todayTasks.isEmpty) {
      response += "오늘은 일정이나 할 일이 없네요. 여유로운 하루를 보내세요!";
    } else {
      if (todayEvents.isNotEmpty) {
        response += "📅 일정 (${todayEvents.length}개):\n";

        for (int i = 0; i < todayEvents.length; i++) {
          final event = todayEvents[i];
          String timeInfo = "";

          if (event['startTime'] != null) {
            if (event['startTime'] is Map) {
              final startHour = event['startTime']['hour'] ?? 0;
              final startMinute = event['startTime']['minute'] ?? 0;
              timeInfo = "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}";

              if (event['endTime'] != null && event['endTime'] is Map) {
                final endHour = event['endTime']['hour'] ?? 0;
                final endMinute = event['endTime']['minute'] ?? 0;
                timeInfo += " ~ ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";
              }
            } else if (event['startTime'] is String) {
              timeInfo = event['startTime'];

              if (event['endTime'] != null && event['endTime'] is String) {
                timeInfo += " ~ ${event['endTime']}";
              }
            }
          }

          response += "${i+1}. ${event['title']}${timeInfo.isNotEmpty ? ' ($timeInfo)' : ''}";

          if (event['location'] != null && event['location'].toString().isNotEmpty) {
            response += " - ${event['location']}";
          }

          response += "\n";
        }

        if (todayTasks.isNotEmpty) {
          response += "\n";
        }
      }

      if (todayTasks.isNotEmpty) {
        final completedTasks = todayTasks.where((task) => task['isCompleted'] == true).length;
        response += "📝 할 일 (${completedTasks}/${todayTasks.length} 완료):\n";

        // 먼저 미완료 항목
        final incompleteTasks = todayTasks.where((task) => task['isCompleted'] != true).toList();
        for (int i = 0; i < incompleteTasks.length; i++) {
          final task = incompleteTasks[i];
          response += "${i+1}. ❌ ${task['title']}";

          if (task['importance'] != null || task['urgency'] != null) {
            response += " (중요도: ${task['importance'] ?? 1}, 긴급도: ${task['urgency'] ?? 1})";
          }

          response += "\n";
        }

        // 완료된 항목
        final completedTasksList = todayTasks.where((task) => task['isCompleted'] == true).toList();
        for (int i = 0; i < completedTasksList.length; i++) {
          final task = completedTasksList[i];
          response += "${incompleteTasks.length + i + 1}. ✅ ${task['title']}\n";
        }
      }
    }

    return {
      "response": response,
      "actions": <Map<String, dynamic>>[]
    };
  }

// 시간 추천 응답 생성
  Future<Map<String, dynamic>> _generateTimeRecommendationResponse(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) async {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 일정 필터링
    final todayEvents = calendar.where((event) {
      return event['date'] == today || (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    // 시간대별 점유 상태 (0-23시)
    final occupiedHours = List<bool>.filled(24, false);

    // 캘린더 일정으로 점유 시간 설정
    for (final event in todayEvents) {
      if (event['startTime'] != null) {
        int startHour = 0;
        int endHour = 0;

        if (event['startTime'] is Map) {
          startHour = event['startTime']['hour'] ?? 0;

          if (event['endTime'] != null && event['endTime'] is Map) {
            endHour = event['endTime']['hour'] ?? (startHour + 1);
          } else {
            endHour = startHour + 1;
          }
        } else if (event['startTime'] is String) {
          final timeParts = event['startTime'].toString().split(':');
          if (timeParts.length >= 1) {
            startHour = int.tryParse(timeParts[0]) ?? 0;
          }

          if (event['endTime'] != null && event['endTime'] is String) {
            final endTimeParts = event['endTime'].toString().split(':');
            if (endTimeParts.length >= 1) {
              endHour = int.tryParse(endTimeParts[0]) ?? (startHour + 1);
            }
          } else {
            endHour = startHour + 1;
          }
        }

        // 시간대 점유 표시
        for (int hour = startHour; hour < endHour; hour++) {
          if (hour >= 0 && hour < 24) {
            occupiedHours[hour] = true;
          }
        }
      }
    }

    // 가용 시간대 찾기 (9AM-9PM 사이)
    final availableTimeSlots = <Map<String, dynamic>>[];

    for (int hour = 9; hour < 21; hour++) {
      if (!occupiedHours[hour]) {
        final slot = {
          'hour': hour,
          'time': '${hour.toString().padLeft(2, '0')}:00',
          'endTime': '${(hour + 1).toString().padLeft(2, '0')}:00',
        };
        availableTimeSlots.add(slot);
      }
    }

    // 결과 생성
    String response = "";
    List<Map<String, dynamic>> actions = [];

    if (availableTimeSlots.isEmpty) {
      response = "오늘은 9시부터 21시까지 모든 시간대가 채워져 있네요. 내일 일정을 계획해보는 것은 어떨까요? 아니면 밤이나 새벽 시간대를 활용하실 수도 있습니다.";
    } else {
      response = "오늘 비어있는 시간대를 찾았습니다:\n\n";

      for (int i = 0; i < min(3, availableTimeSlots.length); i++) {
        final slot = availableTimeSlots[i];
        final hour = slot['hour'] as int;

        String activitySuggestion = "";
        String title = "";

        // 시간대별 활동 추천
        if (hour >= 9 && hour < 12) {
          activitySuggestion = "아침 시간대는 집중력이 높은 시간입니다. 중요한 업무나 공부를 하기 좋습니다.";
          title = "중요 업무/공부";
        } else if (hour >= 12 && hour < 14) {
          activitySuggestion = "점심 시간대입니다. 식사 후 가벼운 산책이나 휴식을 취하기 좋습니다.";
          title = "점심 식사 및 휴식";
        } else if (hour >= 14 && hour < 17) {
          activitySuggestion = "오후 시간대입니다. 미팅이나 협업 업무를 하기 좋은 시간입니다.";
          title = "미팅/협업 업무";
        } else if (hour >= 17 && hour < 19) {
          activitySuggestion = "저녁 시간대입니다. 운동이나 개인 취미 활동을 하기 좋습니다.";
          title = "운동/취미 활동";
        } else {
          activitySuggestion = "늦은 시간대입니다. 간단한 정리나 내일 계획을 세우기 좋습니다.";
          title = "계획 정리";
        }

        response += "🕒 ${slot['time']} ~ ${slot['endTime']}: $activitySuggestion\n\n";

        actions.add({
          "action": "recommend_task",
          "data": {
            "title": title,
            "time": slot['time'],
            "endTime": slot['endTime'],
            "date": today,
            "description": activitySuggestion,
          }
        });
      }

      if (availableTimeSlots.length > 3) {
        response += "그 외에도 ${availableTimeSlots.length - 3}개의 시간대가 더 있습니다.";
      }

      response += "\n\n원하시는 시간대를 선택하시면 일정을 추가해 드릴게요. 다른 활동을 원하시면 말씀해 주세요.";
    }

    return {
      "response": response,
      "actions": actions
    };
  }

  // 빈 시간대 감지 및 일정 추천
  static Future<List<Map<String, dynamic>>> getTimeSlotRecommendations({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
    int? minDurationMinutes,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "calendar": _sanitizeCalendarData(calendar),
        "tasks": _sanitizeTaskData(tasks),
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
        "minDurationMinutes": minDurationMinutes ?? 30, // 기본 30분 단위로 빈 시간 찾기
      };

      // 디버깅
      _printDebugData('/recommend_time_slots', requestData);

      final response = await http.post(
        Uri.parse('$possibleUrls/recommend_time_slots'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('시간대 추천 응답: $data');

        if (data['recommendations'] == null || (data['recommendations'] as List).isEmpty) {
          return [
            {
              "text": "오늘은 빈 시간대가 많지 않네요. 휴식을 충분히 취하시는게 좋겠습니다.",
              "type": "suggestion"
            }
          ];
        }

        return List<Map<String, dynamic>>.from(data['recommendations']);
      } else {
        print("서버 오류(시간대 추천): ${response.statusCode} - ${response.body}");
        return _getDefaultTimeSlotRecommendations(calendar);
      }
    } catch (e) {
      print("통신 오류(시간대 추천): $e");
      return _getDefaultTimeSlotRecommendations(calendar);
    }
  }

  // 일정 추천 기능
  static Future<List<Map<String, dynamic>>> getTaskRecommendations({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "calendar": _sanitizeCalendarData(calendar),
        "tasks": _sanitizeTaskData(tasks),
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
      };

      // 디버깅
      _printDebugData('/recommend_tasks', requestData);

      final response = await http.post(
        Uri.parse('$possibleUrls/recommend_tasks'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('일정 추천 응답: $data');

        if (data['recommendations'] == null || (data['recommendations'] as List).isEmpty) {
          return [
            {
              "text": "현재 일정과 목표를 바탕으로 추천 일정을 찾지 못했습니다. 다른 요청을 해보세요.",
              "type": "suggestion"
            }
          ];
        }

        return List<Map<String, dynamic>>.from(data['recommendations']);
      } else {
        print("서버 오류(일정 추천): ${response.statusCode} - ${response.body}");
        return _getDefaultTaskRecommendations(calendar, tasks);
      }
    } catch (e) {
      print("통신 오류(일정 추천): $e");
      return _getDefaultTaskRecommendations(calendar, tasks);
    }
  }

  // 기본 시간대 추천 (서버 오류 시)
  static List<Map<String, dynamic>> _getDefaultTimeSlotRecommendations(
      List<Map<String, dynamic>> calendar) {
    // 기본 시간대 (9시부터 18시까지)
    final List<String> defaultTimeSlots = [
      "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"
    ];

    // 이미 예약된 시간대 확인
    final List<String> bookedTimeSlots = [];
    for (var event in calendar) {
      if (event.containsKey('startTime') && event['startTime'] != null) {
        String startTime = event['startTime'].toString();
        // 시간만 추출 (HH:mm 형식)
        if (startTime.contains(':')) {
          bookedTimeSlots.add(startTime.split(':').first.padLeft(2, '0') + ":00");
        }
      }
    }

    // 빈 시간대 찾기
    final List<String> freeTimeSlots = defaultTimeSlots
        .where((timeSlot) => !bookedTimeSlots.contains(timeSlot))
        .toList();

    if (freeTimeSlots.isEmpty) {
      return [
        {
          "text": "오늘은 일정이 꽉 차있네요. 휴식 시간을 조금이라도 가지시는게 좋겠습니다.",
          "type": "suggestion"
        }
      ];
    }

    // 추천 시간대 생성
    final recommendations = [
      {
        "text": "오늘 ${freeTimeSlots.first}부터 약 1시간 정도 비어있네요. 중요한 일을 처리하기 좋은 시간입니다.",
        "type": "suggestion",
        "timeSlot": freeTimeSlots.first,
        "action": "recommend_task",
        "data": {
          "time": freeTimeSlots.first,
          "duration": "01:00"
        }
      }
    ];

    if (freeTimeSlots.length > 1) {
      recommendations.add({
        "text": "또한 ${freeTimeSlots[1]}에도 시간이 있습니다. 집중이 필요한 업무나 공부에 활용해보세요.",
        "type": "suggestion",
        "timeSlot": freeTimeSlots[1],
        "action": "recommend_task",
        "data": {
          "time": freeTimeSlots[1],
          "duration": "01:00"
        }
      });
    }

    return recommendations;
  }

  // 기본 일정 추천 (서버 오류 시)
  static List<Map<String, dynamic>> _getDefaultTaskRecommendations(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {

    // 기본 추천 일정 타입
    final List<Map<String, dynamic>> recommendations = [];

    // 투두리스트에서 중요도가 높고 완료되지 않은 작업 확인
    final importantTasks = tasks.where((task) =>
    (task['importance'] != null && int.parse(task['importance'].toString()) >= 3) &&
        (task['isCompleted'] == null || task['isCompleted'] == false)
    ).toList();

    if (importantTasks.isNotEmpty) {
      final task = importantTasks.first;
      recommendations.add({
        "text": "중요한 할 일 '${task['title']}'가 있습니다. 오늘 우선적으로 처리해보는 것이 어떨까요?",
        "type": "suggestion",
        "action": "recommend_task",
        "data": {
          "title": task['title'],
          "importance": task['importance'],
          "urgency": task['urgency'],
        }
      });
    }

    // 일정이 많은 날인지 확인
    final today = DateTime.now().toString().split(' ')[0];
    final todayEvents = calendar.where((event) => event['date'] == today).toList();

    if (todayEvents.length >= 3) {
      recommendations.add({
        "text": "오늘은 일정이 많습니다. 짧은 휴식 시간을 중간중간 가지는 것이 좋겠습니다.",
        "type": "suggestion",
        "action": "recommend_task",
        "data": {
          "title": "짧은 휴식 취하기",
          "duration": "00:15",
          "description": "효율적인 작업을 위한 짧은 휴식",
        }
      });
    } else if (todayEvents.isEmpty && (importantTasks.isEmpty || importantTasks.length < 2)) {
      recommendations.add({
        "text": "오늘은 일정이 많지 않네요. 장기 프로젝트를 진행하거나 자기계발 시간을 가져보는 건 어떨까요?",
        "type": "suggestion",
        "action": "recommend_task",
        "data": {
          "title": "자기계발 시간",
          "duration": "01:30",
          "description": "책읽기, 공부하기 또는 새로운 기술 배우기",
        }
      });
    }

    // 기본 추천이 없으면 기본값 추가
    if (recommendations.isEmpty) {
      recommendations.add({
        "text": "일정 계획을 세워보는 것은 어떨까요? 오늘의 목표를 설정하고 시간을 효율적으로 사용해보세요.",
        "type": "suggestion",
        "action": "recommend_task",
        "data": {
          "title": "오늘의 목표 설정하기",
          "duration": "00:20",
          "description": "하루 계획 세우기",
        }
      });
    }

    return recommendations;
  }

  // 조언 받기 API 호출 - 개선된 버전
  static Future<List<Map<String, dynamic>>> getAdvice({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
  }) async {
    try {
      // 요청할 데이터 준비 - 데이터 구조 확인 및 수정
      final requestData = {
        "calendar": _sanitizeCalendarData(calendar),
        "tasks": _sanitizeTaskData(tasks),
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
        "preferences": {} // 나중에 사용자 설정 추가 가능
      };

      // 디버깅
      _printDebugData('/advice', requestData);

      final response = await http.post(
        Uri.parse('$possibleUrls/advice'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('조언 응답: $data');

        // 응답이 없거나 빈 배열인 경우 기본 메시지 제공
        if (data['messages'] == null || (data['messages'] as List).isEmpty) {
          return _getDefaultAdvice(calendar, tasks);
        }

        return List<Map<String, dynamic>>.from(data['messages']);
      } else {
        print("서버 오류(조언): ${response.statusCode} - ${response.body}");
        return _getDefaultAdvice(calendar, tasks);
      }
    } catch (e) {
      print("통신 오류(조언): $e");
      // 오류 발생 시에도 기본 메시지 제공
      return _getDefaultAdvice(calendar, tasks);
    }
  }

  // 캘린더 데이터 정제 - 서버에서 기대하는 형식으로 변환
  static List<Map<String, dynamic>> _sanitizeCalendarData(List<Map<String, dynamic>> calendar) {
    return calendar.map((event) {
      // 필수 필드 확인 및 변환
      final Map<String, dynamic> sanitizedEvent = {
        "id": event["id"] ?? "cal_${DateTime.now().millisecondsSinceEpoch}",
        "title": event["title"] ?? "무제",
        "date": event["date"] ?? DateTime.now().toString().split(' ')[0],
      };

      // 선택적 필드 추가
      if (event.containsKey("startTime") && event["startTime"] != null) {
        sanitizedEvent["startTime"] = event["startTime"];
      }

      if (event.containsKey("endTime") && event["endTime"] != null) {
        sanitizedEvent["endTime"] = event["endTime"];
      }

      if (event.containsKey("location")) {
        sanitizedEvent["location"] = event["location"];
      }

      if (event.containsKey("description")) {
        sanitizedEvent["description"] = event["description"];
      }

      return sanitizedEvent;
    }).toList();
  }

  // 할 일 데이터 정제 - 서버에서 기대하는 형식으로 변환
  static List<Map<String, dynamic>> _sanitizeTaskData(List<Map<String, dynamic>> tasks) {
    return tasks.map((task) {
      // 필수 필드 확인 및 변환
      final Map<String, dynamic> sanitizedTask = {
        "id": task["id"] ?? "task_${DateTime.now().millisecondsSinceEpoch}",
        "title": task["title"] ?? "무제 할 일",
      };

      // 선택적 필드 추가
      if (task.containsKey("dueDate")) {
        sanitizedTask["dueDate"] = task["dueDate"];
      }

      if (task.containsKey("importance")) {
        sanitizedTask["importance"] = task["importance"];
      } else {
        sanitizedTask["importance"] = "1";  // 기본값 설정
      }

      if (task.containsKey("urgency")) {
        sanitizedTask["urgency"] = task["urgency"];
      } else {
        sanitizedTask["urgency"] = "1";  // 기본값 설정
      }

      if (task.containsKey("isCompleted")) {
        sanitizedTask["isCompleted"] = task["isCompleted"];
      }

      return sanitizedTask;
    }).toList();
  }

  // 기본 조언 메시지 생성 (서버 응답 실패 시)
  static List<Map<String, dynamic>> _getDefaultAdvice(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    final List<Map<String, dynamic>> defaultMessages = [];

    // 캘린더 데이터 기반 메시지
    if (calendar.isNotEmpty) {
      final todayEvents = calendar.where((event) {
        final eventDate = event["date"] as String?;
        final today = DateTime.now().toString().split(' ')[0];
        return eventDate == today;
      }).toList();

      if (todayEvents.isNotEmpty) {
        final firstEvent = todayEvents.first;
        defaultMessages.add({
          "text": "오늘 ${firstEvent['title']} 일정이 있어요. 준비는 잘 되어가고 있나요?",
          "type": "reminder"
        });
      }

      // 내일 일정이 있는지 확인
      final tomorrow = DateTime.now().add(Duration(days: 1)).toString().split(' ')[0];
      final tomorrowEvents = calendar.where((event) => event["date"] == tomorrow).toList();

      if (tomorrowEvents.isNotEmpty) {
        defaultMessages.add({
          "text": "내일 ${tomorrowEvents.length}개의 일정이 있어요. 미리 준비해보세요!",
          "type": "reminder"
        });
      }

      // 앞으로 7일 이내의 일정 확인
      final now = DateTime.now();
      final upcomingEvents = calendar.where((event) {
        final eventDateStr = event["date"] as String?;
        if (eventDateStr == null) return false;

        final eventDate = DateTime.tryParse(eventDateStr);
        if (eventDate == null) return false;

        final difference = eventDate.difference(now).inDays;
        return difference > 0 && difference <= 7;
      }).toList();

      // 여행 관련 일정 찾기
      final travelEvents = upcomingEvents.where((event) {
        final title = event["title"]?.toString().toLowerCase() ?? "";
        return title.contains('여행') || title.contains('trip') || title.contains('vacation');
      }).toList();

      if (travelEvents.isNotEmpty) {
        final travelEvent = travelEvents.first;
        final title = travelEvent["title"] ?? "";
        final dateStr = travelEvent["date"] as String?;
        final eventDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        String daysLeft = "";
        if (eventDate != null) {
          final difference = eventDate.difference(now).inDays;
          daysLeft = "$difference일 후";
        }

        defaultMessages.add({
          "text": "$daysLeft $title 예정이시군요! 여행 준비는 잘 되고 있나요? 숙소와 교통편은 확인하셨나요?",
          "type": "reminder"
        });
      }

      // 시험/테스트 관련 일정 찾기
      final examEvents = upcomingEvents.where((event) {
        final title = event["title"]?.toString().toLowerCase() ?? "";
        return title.contains('시험') || title.contains('테스트') || title.contains('exam') || title.contains('test');
      }).toList();

      if (examEvents.isNotEmpty) {
        final examEvent = examEvents.first;
        final title = examEvent["title"] ?? "";
        final dateStr = examEvent["date"] as String?;
        final eventDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        String daysLeft = "";
        if (eventDate != null) {
          final difference = eventDate.difference(now).inDays;
          daysLeft = "$difference일 후";
        }

        defaultMessages.add({
          "text": "$daysLeft $title 예정이시군요! 시험 공부는 계획대로 진행되고 있나요?",
          "type": "reminder"
        });
      }
    }

    // 할 일 데이터 기반 메시지
    if (tasks.isNotEmpty) {
      final completedTasks = tasks.where((task) => task["isCompleted"] == true).length;
      final totalTasks = tasks.length;

      if (completedTasks > 0) {
        defaultMessages.add({
          "text": "오늘 ${completedTasks}/${totalTasks} 할 일을 완료했어요! 정말 잘하고 있어요!",
          "type": "encouragement"
        });
      } else {
        defaultMessages.add({
          "text": "오늘 할 일이 ${totalTasks}개 있어요. 하나씩 천천히 해보아요!",
          "type": "suggestion"
        });
      }

      // 마감일이 있는 할 일 확인
      final tasksWithDueDate = tasks.where((task) =>
      task["dueDate"] != null &&
          task["dueDate"].toString().isNotEmpty &&
          task["dueDate"] != "없음"
      ).toList();

      if (tasksWithDueDate.isNotEmpty) {
        defaultMessages.add({
          "text": "마감일이 있는 할 일을 우선적으로 확인해보세요!",
          "type": "alert"
        });
      }

      // 공부 관련 할 일 확인
      final studyTasks = tasks.where((task) {
        final title = task["title"]?.toString().toLowerCase() ?? "";
        return title.contains('공부') || title.contains('학습') || title.contains('study') ||
            title.contains('모의고사') || title.contains('test');
      }).toList();

      if (studyTasks.isNotEmpty) {
        final studyTask = studyTasks.first;
        final title = studyTask["title"] ?? "";

        if (title.toLowerCase().contains('모의고사')) {
          defaultMessages.add({
            "text": "$title가 계획되어 있네요. 몇 회차 모의고사인가요? 잘 준비되고 있나요?",
            "type": "inquiry"
          });
        } else {
          defaultMessages.add({
            "text": "$title가 계획되어 있네요. 학습 계획은 잘 세우셨나요?",
            "type": "inquiry"
          });
        }
      }
    }

    // 기본 메시지가 없으면 추가
    if (defaultMessages.isEmpty) {
      defaultMessages.add({
        "text": "오늘의 일정과 할 일을 관리하는 것을 도와드릴게요!",
        "type": "greeting"
      });

      defaultMessages.add({
        "text": "시간을 효율적으로 사용하고 싶으신가요? 오늘의 목표를 설정해보세요!",
        "type": "suggestion"
      });
    }

    return defaultMessages;
  }

  // 맞춤형 조언 메시지 생성 (이벤트 키워드 기반)
  static Future<List<Map<String, dynamic>>> getContextualAdvice({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    // 서버 API 호출 - 맞춤형 조언 기능 활용
    try {
      return await getAdvice(calendar: calendar, tasks: tasks);
    } catch (e) {
      print("맞춤형 조언 생성 오류: $e");

      // 오류 시 기본 키워드 분석 로직으로 대체
      return _generateKeywordBasedAdvice(calendar, tasks);
    }
  }
  // 키워드 기반 맞춤형 조언 생성 함수
  static List<Map<String, dynamic>> _generateKeywordBasedAdvice(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    final List<Map<String, dynamic>> contextualAdvice = [];

    // 캘린더에서 키워드 기반 조언
    for (final event in calendar) {
      final title = event['title'].toString().toLowerCase();
      final eventDate = event['date'] != null ? DateTime.tryParse(event['date'].toString()) : null;
      final today = DateTime.now();

      // 날짜 차이 계산 (며칠 전/후인지)
      int daysDifference = 0;
      if (eventDate != null) {
        daysDifference = eventDate.difference(today).inDays;
      }

      // 여행 관련 일정
      if (title.contains('여행') || title.contains('trip')) {
        String destination = '';

        if (title.contains('일본')) destination = '일본';
        else if (title.contains('미국')) destination = '미국';
        else if (title.contains('유럽')) destination = '유럽';
        else if (title.contains('제주')) destination = '제주';
        else if (title.contains('부산')) destination = '부산';

        if (destination.isNotEmpty) {
          String advice = "$destination 여행 준비는 잘 되고 있나요?";

          // 여행 날짜가 7일 이내면 준비물 체크리스트 제안
          if (daysDifference >= 0 && daysDifference <= 7) {
            advice += " 여행 준비물 체크리스트를 확인해보세요. 여권, 숙소/항공권 예약 확인, 환전 등 필수 항목을 체크하셨나요?";
          }
          // 여행 날짜가 1달 이내면 호텔/항공권 예약 확인
          else if (daysDifference > 7 && daysDifference <= 30) {
            advice += " 호텔과 항공권은 예약하셨나요? 현지 날씨도 미리 확인해보세요.";
          }

          contextualAdvice.add({
            "text": advice,
            "type": "suggestion"
          });
        } else {
          contextualAdvice.add({
            "text": "여행 준비는 잘 되고 있나요? 필요한 준비물 목록을 만들어보세요!",
            "type": "suggestion"
          });
        }
      }

      // 미팅/회의 관련 일정
      else if (title.contains('회의') || title.contains('미팅') || title.contains('meeting')) {
        String advice = "다가오는 회의 준비는 잘 되고 있나요?";

        // 오늘 회의라면
        if (daysDifference == 0) {
          advice = "오늘 회의가 있습니다. 필요한 자료는 모두 준비되었나요? 시간에 늦지 않도록 준비해주세요.";
        }
        // 내일 회의라면
        else if (daysDifference == 1) {
          advice = "내일 회의가 있습니다. 발표 자료나 회의 안건을 미리 점검해보세요.";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "reminder"
        });
      }

      // 시험 관련 일정
      else if (title.contains('시험') || title.contains('테스트') || title.contains('exam')) {
        String advice = "시험 준비는 잘 되고 있나요?";

        // 오늘 시험이라면
        if (daysDifference == 0) {
          advice = "오늘 시험이 있습니다. 시험 시간과 장소를 다시 한번 확인하시고, 필요한 준비물을 챙기세요.";
        }
        // 시험이 일주일 이내라면
        else if (daysDifference > 0 && daysDifference <= 7) {
          advice = "시험이 ${daysDifference}일 남았습니다. 핵심 주제를 중심으로 마무리 복습 계획을 세워보세요.";
        }
        // 시험이 한 달 이내라면
        else if (daysDifference > 7 && daysDifference <= 30) {
          advice = "시험이 약 ${(daysDifference / 7).round()}주 남았습니다. 체계적인 학습 계획을 세워 효율적으로 준비하세요.";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "suggestion"
        });
      }

      // 생일 관련 일정
      else if (title.contains('생일') || title.contains('birthday')) {
        String advice = "생일 축하 메시지나 선물 준비는 잘 되고 있나요?";

        // 오늘이 생일이라면
        if (daysDifference == 0) {
          if (title.contains('내') || title.contains('my')) {
            advice = "오늘은 당신의 생일이군요! 🎂 행복한 하루 되세요. 특별한 계획이 있으신가요?";
          } else {
            advice = "오늘은 누군가의 생일이군요! 축하 메시지를 보내시거나 축하 전화를 드려보세요.";
          }
        }
        // 생일이 일주일 이내라면
        else if (daysDifference > 0 && daysDifference <= 7) {
          advice = "곧 생일이 다가오네요. 선물이나 축하 준비는 하셨나요?";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "reminder"
        });
      }

      // 공연/콘서트 관련 일정
      else if (title.contains('공연') || title.contains('콘서트') || title.contains('concert') || title.contains('show')) {
        String advice = "공연 준비는 잘 되고 있나요? 티켓은 안전하게 보관하고 계신가요?";

        // 당일이라면
        if (daysDifference == 0) {
          advice = "오늘 공연이 있습니다! 티켓과 신분증을 꼭 확인하시고, 공연장 위치와 시간을 미리 체크하세요.";
        }
        // 하루 전이라면
        else if (daysDifference == 1) {
          advice = "내일 공연입니다. 티켓 확인과 교통편을 미리 계획해두세요.";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "reminder"
        });
      }
    }

    // 할 일에서 키워드 기반 조언
    for (final task in tasks) {
      final title = task['title'].toString().toLowerCase();
      final dueDate = task['dueDate'] != null && task['dueDate'] != '없음'
          ? DateTime.tryParse(task['dueDate'].toString())
          : null;
      final today = DateTime.now();

      // 날짜 차이 계산
      int daysDifference = 0;
      if (dueDate != null) {
        daysDifference = dueDate.difference(today).inDays;
      }

      // 마감일이 가까운 과제
      if ((title.contains('과제') || title.contains('숙제') || title.contains('assignment')) &&
          dueDate != null) {
        String advice = "과제 마감일이 다가오고 있어요! 시간 관리에 유의하세요.";

        // 오늘 마감이라면
        if (daysDifference == 0) {
          advice = "오늘이 과제 마감일입니다! 최종 점검 후 제출하세요.";
        }
        // 내일 마감이라면
        else if (daysDifference == 1) {
          advice = "과제 마감일이 내일입니다. 완성도를 높이기 위한 최종 검토를 진행하세요.";
        }
        // 3일 이내 마감이라면
        else if (daysDifference > 1 && daysDifference <= 3) {
          advice = "과제 마감이 ${daysDifference}일 남았습니다. 작업 속도를 높여 완성도를 챙기세요.";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "alert"
        });
        break;  // 중복 메시지 방지
      }

      // 프로젝트 관련 할 일
      else if (title.contains('프로젝트') || title.contains('project')) {
        String advice = "프로젝트 진행 상황을 체크해보세요. 계획대로 진행되고 있나요?";

        // 마감일이 있고 7일 이내라면
        if (dueDate != null && daysDifference >= 0 && daysDifference <= 7) {
          advice = "프로젝트 마감이 ${daysDifference}일 남았습니다. 주요 마일스톤을 점검하고 팀원들과 진행 상황을 공유하세요.";
        }

        contextualAdvice.add({
          "text": advice,
          "type": "suggestion"
        });
        break;  // 중복 메시지 방지
      }

      // 운동 관련 할 일
      else if (title.contains('운동') || title.contains('헬스') || title.contains('workout') || title.contains('gym')) {
        contextualAdvice.add({
          "text": "오늘의 운동 계획이 있군요! 꾸준한 운동은 건강과 정신 건강에 매우 중요합니다. 화이팅하세요!",
          "type": "encouragement"
        });
        break;  // 중복 메시지 방지
      }

      // 독서 관련 할 일
      else if (title.contains('독서') || title.contains('책') || title.contains('읽기') || title.contains('reading') || title.contains('book')) {
        contextualAdvice.add({
          "text": "독서 시간을 계획하셨군요. 조용한 환경에서 집중해서 읽으면 더 효과적일 거예요.",
          "type": "suggestion"
        });
        break;  // 중복 메시지 방지
      }

      // 모의고사 관련 할 일
      else if (title.contains('모의고사') || title.contains('모고')) {
        contextualAdvice.add({
          "text": "모의고사 공부를 계획하셨군요! 몇 회차 모의고사인가요? 어떤 과목에 중점을 두고 계신가요?",
          "type": "inquiry"
        });
        break;  // 중복 메시지 방지
      }
    }

    // 조언이 없으면 기본 조언 사용
    if (contextualAdvice.isEmpty) {
      return _getDefaultAdvice(calendar, tasks);
    }

    return contextualAdvice;
  }

  // 빈 시간대 찾기 헬퍼 함수
  static List<String> _findFreeTimeSlots(List<Map<String, dynamic>> calendar) {
    // 기본 시간대 (9시부터 18시까지 1시간 단위)
    final List<String> defaultTimeSlots = [
      "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"
    ];

    // 이미 예약된 시간대 찾기
    final List<String> bookedTimeSlots = [];
    final today = DateTime.now().toString().split(' ')[0];

    for (var event in calendar) {
      if (event['date'] == today &&
          event.containsKey('startTime') &&
          event['startTime'] != null) {
        String startTime = event['startTime'].toString();
        // 시간만 추출 (HH:mm 형식)
        if (startTime.contains(':')) {
          bookedTimeSlots.add(startTime.split(':').first.padLeft(2, '0') + ":00");
        }
      }
    }

    // 빈 시간대 반환
    return defaultTimeSlots
        .where((timeSlot) => !bookedTimeSlots.contains(timeSlot))
        .toList();
  }

  // 기본 응답 생성 (서버 연결 실패 시)
  static Map<String, dynamic> _getFallbackResponse(
      String message,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {

    // 메시지 내용에 따른 기본 응답 생성
    String response = "";
    List<Map<String, dynamic>> actions = [];

    // 메시지 키워드 분석
    final lowerMessage = message.toLowerCase();

    // 인사말 관련 키워드
    if (lowerMessage.contains('안녕') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('hello')) {
      response = "안녕하세요! 오늘 하루도 계획적으로 보내실 수 있도록 도와드릴게요. 무엇을 도와드릴까요?";
    }

    // 일정 추가 요청 감지
    else if ((lowerMessage.contains('일정') || lowerMessage.contains('할 일') || lowerMessage.contains('todo')) &&
        (lowerMessage.contains('추가') || lowerMessage.contains('만들') || lowerMessage.contains('생성'))) {

      // 간단한 일정 정보 추출 시도
      String title = "새 일정";
      String time = "";
      String date = DateTime.now().toString().split(' ')[0];

      // 제목 추출 시도
      final titleMatch = RegExp(r'제목[은는이가]?\s*[:\s]?\s*([가-힣a-zA-Z0-9\s]+)').firstMatch(message);
      if (titleMatch != null && titleMatch.group(1) != null) {
        title = titleMatch.group(1)!.trim();
      }

      // 시간 추출 시도
      final timeMatch = RegExp(r'(\d{1,2})[시:](\d{0,2})').firstMatch(message);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = timeMatch.group(2)!.isEmpty ? 0 : int.parse(timeMatch.group(2)!);
        time = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      }

      response = "일정을 추가해드릴게요. 제목은 '$title'이고, ${time.isNotEmpty ? '$time에' : '오늘'} 예정된 일정입니다. 더 자세한 정보가 필요하시면 말씀해주세요.";

      // 일정 추가 액션 생성
      actions.add({
        "action": "add_task",
        "data": {
          "title": title,
          "date": date,
          "time": time,
        }
      });
    }

    // 일정 삭제 요청 감지
    else if ((lowerMessage.contains('일정') || lowerMessage.contains('할 일') || lowerMessage.contains('todo')) &&
        (lowerMessage.contains('삭제') || lowerMessage.contains('지워') || lowerMessage.contains('취소'))) {

      // 삭제할 일정 제목 추출 시도
      String title = "";

      // 메시지에서 일정 제목 찾기
      for (var task in tasks) {
        final taskTitle = task['title'].toString();
        if (message.contains(taskTitle)) {
          title = taskTitle;
          break;
        }
      }

      if (title.isNotEmpty) {
        response = "'$title' 일정을 삭제합니다. 다른 도움이 필요하신가요?";

        // 제목을 찾았다면 삭제 액션 추가
        actions.add({
          "action": "delete_task",
          "data": {
            "title": title,
          }
        });
      } else {
        response = "삭제할 일정을 찾지 못했습니다. 삭제하려는 일정의 정확한 제목을 알려주시겠어요?";
      }
    }

    // 일정 추천 요청 감지
    else if (lowerMessage.contains('추천') &&
        (lowerMessage.contains('일정') || lowerMessage.contains('할 일') || lowerMessage.contains('시간'))) {

      response = "현재 일정과 할 일을 기반으로 맞춤 일정을 추천해드릴게요. ";

      // 비어있는 시간대 찾기
      final freeTimeSlots = _findFreeTimeSlots(calendar);

      if (freeTimeSlots.isNotEmpty) {
        final slot = freeTimeSlots.first;
        response += "오늘 $slot에 시간이 비어있네요. 이 시간에 중요한 작업을 처리하는 것이 어떨까요? 일정을 추가해드릴까요?";

        // 시간대 추천 액션 생성
        actions.add({
          "action": "recommend_task",
          "data": {
            "time": slot,
            "title": "중요 작업 처리",
            "duration": "01:00",
          }
        });
      } else {
        response += "오늘은 일정이 많이 있네요. 짧은 휴식 시간을 가지는 것이 좋겠습니다. 15분 휴식 일정을 추가해드릴까요?";

        // 시간이 부족한 경우 짧은 휴식 추천
        actions.add({
          "action": "recommend_task",
          "data": {
            "time": "12:00",
            "title": "짧은 휴식",
            "duration": "00:15",
          }
        });
      }
    }

    // 일정 확인 관련 키워드
    else if (lowerMessage.contains('일정') ||
        lowerMessage.contains('스케줄') ||
        lowerMessage.contains('calendar')) {

      int todayEventCount = 0;
      String firstEventTitle = "";

      // 오늘 일정 확인
      final today = DateTime.now().toString().split(' ')[0];
      for (var event in calendar) {
        if (event['date'] == today) {
          todayEventCount++;
          if (todayEventCount == 1) {
            firstEventTitle = event['title'].toString();
          }
        }
      }

      if (todayEventCount > 0) {
        response = "오늘은 총 $todayEventCount개의 일정이 있습니다. ";
        if (todayEventCount == 1) {
          response += "'$firstEventTitle' 일정이 있습니다.";
        } else {
          response += "첫 번째 일정은 '$firstEventTitle'입니다.";
        }
      } else {
        response = "오늘은 예정된 일정이 없습니다. 자유롭게 시간을 활용해보세요!";
      }

      // 일정 확인 액션 추가
      actions.add({
        "action": "view_calendar",
        "data": {
          "date": today
        }
      });
    }

    // 할 일 관련 키워드
    else if (lowerMessage.contains('할 일') ||
        lowerMessage.contains('todo') ||
        lowerMessage.contains('task')) {

      int totalTasks = tasks.length;
      int completedTasks = tasks.where((task) => task["isCompleted"] == true).length;

      if (totalTasks > 0) {
        response = "현재 총 $totalTasks개의 할 일 중 $completedTasks개를 완료했습니다. ";

        // 미완료 할 일이 있으면 중요한 할 일 표시
        if (completedTasks < totalTasks) {
          final incompleteTasks = tasks.where((task) => task["isCompleted"] != true).toList();
          if (incompleteTasks.isNotEmpty) {
            // 중요도/긴급도가 높은 할 일 찾기
            final importantTasks = incompleteTasks.where((task) =>
            (task['importance'] != null && int.parse(task['importance'].toString()) >= 3) ||
                (task['urgency'] != null && int.parse(task['urgency'].toString()) >= 3)
            ).toList();

            if (importantTasks.isNotEmpty) {
              response += "중요한 할 일: '${importantTasks.first['title']}'을 우선적으로 처리하세요.";
            } else {
              response += "다음 할 일: '${incompleteTasks.first['title']}'을 진행해보세요.";
            }
          }
        } else {
          response += "모든 할 일을 완료했습니다! 정말 잘하셨어요.";
        }
      } else {
        response = "할 일 목록이 비어있습니다. 오늘의 목표를 설정해보는 건 어떨까요?";
      }

      // 할 일 보기 액션 추가
      actions.add({
        "action": "view_tasks",
        "data": {}
      });
    }

    // '오늘 뭐해야 할까?' 같은 질문에 대한 처리
    else if (lowerMessage.contains('뭐해') ||
        lowerMessage.contains('뭐 해') ||
        lowerMessage.contains('할까') ||
        lowerMessage.contains('좋을까')) {

      // 일정이 있는지 확인
      if (calendar.isNotEmpty) {
        final today = DateTime.now().toString().split(' ')[0];
        final todayEvents = calendar.where((event) => event['date'] == today).toList();

        if (todayEvents.isNotEmpty) {
          response = "오늘 일정을 확인해보니 다음과 같은 일정이 있어요:\n\n";
          int count = 0;
          for (var event in todayEvents) {
            if (count < 3) {
              String time = event['startTime'] != null ? "${event['startTime']} - " : "";
              response += "- $time${event['title']}\n";
              count++;
            } else {
              break;
            }
          }

          if (todayEvents.length > 3) {
            response += "\n그 외 ${todayEvents.length - 3}개의 일정이 더 있습니다.";
          }

          response += "\n\n이 일정들을 우선 처리하는 것이 좋을 것 같아요.";
        }
      }

      // 할 일이 있는지 확인
      else if (tasks.isNotEmpty) {
        final incompleteTasks = tasks.where((task) => task["isCompleted"] != true).toList();

        if (incompleteTasks.isNotEmpty) {
          response = "오늘 할 일 목록을 확인해보니 다음과 같은 할 일이 있어요:\n\n";
          int count = 0;
          for (var task in incompleteTasks) {
            if (count < 3) {
              response += "- ${task['title']}\n";
              count++;
            } else {
              break;
            }
          }

          if (incompleteTasks.length > 3) {
            response += "\n그 외 ${incompleteTasks.length - 3}개의 할 일이 더 있습니다.";
          }

          response += "\n\n이 할 일들을 처리하는 것이 좋을 것 같아요. 시간대별 추천 일정을 원하시면 알려주세요.";
        }
      }

      // 일정과 할 일이 모두 없는 경우
      if (response.isEmpty) {
        response = "오늘은 특별히 예정된 일정이나 할 일이 없네요. 취미 활동을 하거나, 독서, 운동 등 자기계발 시간을 가져보는 건 어떨까요?";
      }

      // 추천 일정 액션 추가
      actions.add({
        "action": "recommend_task",
        "data": {
          "type": "suggestion"
        }
      });
    }

    // 기본 응답
    else {
      response = "죄송합니다. 지금은 서버 연결에 문제가 있어 자세한 답변을 드리기 어렵습니다. 일정 관리나 시간 추천 등의 기능을 이용해보세요.";
    }

    // 최종 응답 반환
    return {
      "response": response,
      "actions": actions,
      "options": generateRecommendationOptions(calendar, tasks)
    };
  }
}