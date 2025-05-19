import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  // Gemini API 엔드포인트 및 키
  static const String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  // 사용자 ID
  late final String userId;

  // Firebase 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // API 키
  late String _apiKey;

  ChatService({required this.userId}) {
    // 배포 버전용 API 키 직접 설정 (실제 키로 교체 필요)
    _apiKey = "AIzaSyDNfd7f0Bgg0K1d_95HXMMvUXiQ9FqdkRQ";

    // Firebase에서도 로드 시도
    _loadApiKey();
  }

  // Firebase에서 API 키 로드
  Future<void> _loadApiKey() async {
    try {
      // API 키는 보안을 위해 Firebase에 저장
      final apiKeyDoc = await _firestore.collection('config').doc('api_keys').get();
      final firebaseKey = apiKeyDoc.data()?['gemini_api_key'] ?? '';

      if (firebaseKey.isNotEmpty) {
        _apiKey = firebaseKey;  // Firebase에서 키를 찾으면 사용
        print('Firebase에서 API 키 로드 성공');
      }
    } catch (e) {
      print('Firebase API 키 로드 중 오류: $e');
      // 이미 하드코딩된 키가 있으므로 오류가 발생해도 계속 진행
    }
  }

  // 오프라인 응답 생성 (서버/API 연결 실패시 사용)
  Map<String, dynamic> generateOfflineResponse(String message) {
    // 사용자 메시지 중 키워드 분석
    message = message.toLowerCase();

    // 오늘 날짜
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 기본 응답
    Map<String, dynamic> response = {
      "response": "현재 서버 연결이 원활하지 않아 기본 응답만 제공할 수 있습니다. 인터넷 연결을 확인해주세요.",
      "actions": []
    };

    // 키워드에 따른 응답
    if (message.contains("안녕") || message.contains("반가워")) {
      response["response"] = "안녕하세요! 오늘도 좋은 하루 되세요. (오프라인 모드)";
    }
    else if (message.contains("일정") && message.contains("추가")) {
      response["response"] = "일정을 추가하려면 제목, 날짜, 시간 정보가 필요합니다. 예: '내일 3시에 미팅 일정 추가해줘' (오프라인 모드)";
    }
    else if (message.contains("추천") || message.contains("빈 시간")) {
      // 기본 추천 제공
      response["response"] = "오늘 남은 시간에 할 만한 활동으로 독서, 운동, 또는 계획 세우기를 추천드립니다. (오프라인 모드)";
    }
    else if (message.contains("도움말") || message.contains("어떻게") || message.contains("사용")) {
      response["response"] = "저는 일정 관리와 시간 계획을 도와드리는 AI 비서입니다. 일정 추가, 삭제, 추천 등의 기능을 사용해보세요. (오프라인 모드)";
    }

    return response;
  }

  // Gemini API를 사용한 일정 분석 및 추천
  Future<Map<String, dynamic>?> analyzeScheduleForRecommendations({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    try {
      // API 키 확인
      if (_apiKey.isEmpty) {
        print('API 키가 설정되지 않았습니다.');
        return null;
      }

      // 현재 날짜 및 시간
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 프롬프트 작성
      final prompt = '''
당신은 일정 관리 앱의 AI 비서입니다. 사용자의 일정과 할 일 목록을 분석하여 빈 시간대에 할 만한 활동이나 작업을 추천해주세요.

오늘 날짜: $formattedDate

사용자의 캘린더 일정:
${jsonEncode(calendar)}

사용자의 할 일 목록:
${jsonEncode(tasks)}

다음 형식으로 빈 시간대를 찾아 최대 3개의 활동이나 작업을 추천해주세요:
1. 빈 시간대 분석: 사용자의 일정에서 빈 시간대를 파악하여 설명
2. 추천 활동 목록: 빈 시간에 할 만한 활동이나 작업을 3개 이내로 추천
3. 각 추천의 이유: 왜 이 활동이나 작업을 추천하는지 간략히 설명

JSON 형식으로 응답을 구성해주세요: 
{
  "freeTimeSlots": [
    {"startTime": "시작 시간", "endTime": "종료 시간", "duration": "지속 시간"}
  ],
  "recommendations": [
    {
      "title": "추천 활동 제목",
      "description": "활동 설명",
      "reason": "추천 이유",
      "date": "yyyy-mm-dd",
      "time": "시작 시간(선택)",
      "endTime": "종료 시간(선택)",
      "importance": 중요도(1-5),
      "urgency": 긴급도(1-5),
      "memo": "메모(선택)"
    }
  ],
  "summary": "분석 요약"
}
''';

      // API 요청 데이터
      final requestData = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 0.8,
          "maxOutputTokens": 2048,
          "responseMimeType": "application/json",
        }
      };

      // API 요청 보내기
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 10));  // 타임아웃 추가

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        // JSON 문자열 추출 및 파싱
        try {
          // JSON 부분만 추출
          final jsonStart = text.indexOf('{');
          final jsonEnd = text.lastIndexOf('}') + 1;

          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonString = text.substring(jsonStart, jsonEnd);
            final recommendations = jsonDecode(jsonString);
            return recommendations;
          }
        } catch (e) {
          print('JSON 파싱 오류: $e');
          print('원본 텍스트: $text');
        }
      } else {
        print('API 응답 오류: ${response.statusCode}, ${response.body}');
      }

      // 오류 발생 시 기본 응답 생성
      return {
        "freeTimeSlots": [],
        "recommendations": [
          {
            "title": "독서 시간",
            "description": "자기계발 도서 읽기",
            "reason": "지식 확장과 휴식에 좋습니다",
            "date": formattedDate,
            "time": "16:00",
            "endTime": "17:00",
            "importance": 3,
            "urgency": 2,
            "memo": "오프라인 모드로 생성된 기본 추천입니다"
          }
        ],
        "summary": "오프라인 모드로 생성된 기본 추천입니다"
      };
    } catch (e) {
      print('일정 분석 중 오류: $e');

      // 오류 발생 시 기본 응답 생성
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      return {
        "freeTimeSlots": [],
        "recommendations": [
          {
            "title": "독서 시간",
            "description": "자기계발 도서 읽기",
            "reason": "지식 확장과 휴식에 좋습니다",
            "date": formattedDate,
            "time": "16:00",
            "endTime": "17:00",
            "importance": 3,
            "urgency": 2,
            "memo": "오프라인 모드로 생성된 기본 추천입니다"
          }
        ],
        "summary": "오프라인 모드로 생성된 기본 추천입니다"
      };
    }
  }

  // Gemini API를 사용한 대화 처리
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
  }) async {
    try {
      // API 키 확인
      if (_apiKey.isEmpty) {
        return generateOfflineResponse(message);
      }

      // 현재 날짜 및 시간
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 대화 기록 형식화
      final formattedHistory = history.map((msg) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        return {"role": role, "parts": [{"text": msg['content']}]};
      }).toList();

      // 시스템 프롬프트
      final systemPrompt = {
        "role": "system",
        "parts": [
          {
            "text": '''
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

사용자가 "네", "예", "좋아요" 등의 긍정적인 대답을 하면, 이전에 제안한 작업을 실행하세요.
항상 친절하고 도움이 되도록 대화하며, 한국어로 응답하세요.
'''
          }
        ]
      };

      // 대화 목록에 시스템 프롬프트 추가
      final conversationHistory = [systemPrompt, ...formattedHistory];

      // 사용자 메시지 추가
      conversationHistory.add({
        "role": "user",
        "parts": [{"text": message}]
      });

      // API 요청 데이터
      final requestData = {
        "contents": conversationHistory,
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 2048,
          "responseMimeType": "application/json",
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
            final parsedResponse = jsonDecode(jsonString);

            // 액션 필드가 없으면 빈 배열 추가
            if (!parsedResponse.containsKey('actions')) {
              parsedResponse['actions'] = [];
            }

            return parsedResponse;
          } else {
            // JSON이 없는 경우 텍스트만 반환
            return {
              "response": text,
              "actions": []
            };
          }
        } catch (e) {
          print('JSON 파싱 오류: $e');
          print('원본 텍스트: $text');

          // 파싱 오류 시 텍스트만 반환
          return {
            "response": text,
            "actions": []
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

  // 숫자 앞에 0 붙이기 (날짜 형식)
  String _padZero(int num) {
    return num.toString().padLeft(2, '0');
  }
}