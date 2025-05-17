import 'dart:convert';
import 'package:http/http.dart' as http;

class AIAdviceService {
  // 서버 주소는 환경에 맞게 변경 필요
  static const String baseUrl = "http://192.168.219.110:5001"; // Flask 서버 주소

  // 디버깅용 - 데이터 출력
  static void _printDebugData(String endpoint, Map<String, dynamic> data) {
    print('===== 요청 정보 (${endpoint}) =====');
    print('데이터: ${jsonEncode(data)}');
  }

  // 조언 받기 API 호출
  static Future<List<Map<String, dynamic>>> getAdvice({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "calendar": calendar,
        "tasks": tasks,
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
        "preferences": {} // 나중에 사용자 설정 추가 가능
      };

      // 디버깅
      _printDebugData('/advice', requestData);

      final response = await http.post(
        Uri.parse('$baseUrl/advice'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('조언 응답: $data');
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      } else {
        print("서버 오류(조언): ${response.statusCode} - ${response.body}");
        return [{"text": "조언을 불러오는데 실패했습니다.", "type": "alert"}];
      }
    } catch (e) {
      print("통신 오류(조언): $e");
      return [{"text": "서버 연결에 실패했습니다.", "type": "alert"}];
    }
  }

  // 챗봇 API 호출
  static Future<String> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      // 캘린더 데이터 정제
      final sanitizedCalendar = calendar.map((event) {
        // 필요한 필드만 포함하거나 데이터 형식 변환 (필요에 따라 수정)
        return {
          "id": event["id"],
          "title": event["title"],
          "start": event["start"],
          "end": event["end"],
          "description": event["description"] ?? "",
          "location": event["location"] ?? "",
        };
      }).toList();

      // 할 일 데이터 정제
      final sanitizedTasks = tasks.map((task) {
        // 필요한 필드만 포함하거나 데이터 형식 변환 (필요에 따라 수정)
        return {
          "id": task["id"],
          "title": task["title"],
          "description": task["description"] ?? "",
          "dueDate": task["dueDate"] ?? "",
          "completed": task["completed"] ?? false,
          "priority": task["priority"] ?? "medium",
        };
      }).toList();

      // 요청할 데이터 준비
      final requestData = {
        "message": message,
        "context": {
          "calendar": sanitizedCalendar,
          "tasks": sanitizedTasks,
        },
        "history": history ?? []
      };

      // 디버깅 - 요청 데이터 상세 출력
      print('===== 챗봇 요청 상세 정보 =====');
      print('메시지: $message');
      print('캘린더 데이터: ${jsonEncode(sanitizedCalendar)}');
      print('할 일 데이터: ${jsonEncode(sanitizedTasks)}');
      print('==============================');

      final response = await http.post(
        Uri.parse('$baseUrl/chatbot'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('챗봇 응답: $data');

        // 응답 구조 확인
        if (data.containsKey('response')) {
          final responseText = data['response'].toString();
          if (responseText.isNotEmpty) {
            return responseText;
          }
        }

        // 응답이 예상 형식이 아닌 경우
        final responseString = data.toString();
        if (responseString.contains('json') || responseString.contains('response')) {
          try {
            // JSON 형식을 추출하려고 시도
            final jsonPattern = RegExp(r'{.*}', dotAll: true);
            final match = jsonPattern.firstMatch(responseString);
            if (match != null) {
              final extractedJson = jsonDecode(match.group(0)!);
              if (extractedJson.containsKey('response')) {
                return extractedJson['response'];
              }
            }
          } catch (e) {
            print("응답 파싱 오류: $e");
          }
        }

        // 기본 응답으로 fallback
        return _getDefaultResponse(message, calendar, tasks);
      } else {
        print("서버 오류(챗봇): ${response.statusCode} - ${response.body}");
        return _getDefaultResponse(message, calendar, tasks);
      }
    } catch (e) {
      print("통신 오류(챗봇): $e");
      return _getDefaultResponse(message, calendar, tasks);
    }
  }

  // 기본 응답 생성 함수 (서버 오류 또는 응답 파싱 실패 시 사용)
  static String _getDefaultResponse(
      String message,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    // 사용자 메시지 내용에 따라 적절한 기본 응답 반환
    if (message.toLowerCase().contains('일정') || message.toLowerCase().contains('스케줄')) {
      // 오늘 일정 관련 기본 응답
      int eventCount = calendar.length;
      return "현재 $eventCount개의 일정이 있습니다. 서버 연결에 문제가 있어 자세한 정보를 제공하지 못합니다. 잠시 후 다시 시도해주세요.";
    }
    else if (message.toLowerCase().contains('할 일') || message.toLowerCase().contains('태스크')) {
      // 할 일 관련 기본 응답
      int taskCount = tasks.length;
      return "현재 $taskCount개의 할 일이 있습니다. 서버 연결에 문제가 있어 자세한 정보를 제공하지 못합니다. 잠시 후 다시 시도해주세요.";
    }
    else {
      // 기본 응답
      return "죄송합니다. 현재 서버 연결에 문제가 있어 요청을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.";
    }
  }
}