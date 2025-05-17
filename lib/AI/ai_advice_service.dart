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

  // 챗봇 대화 API 호출
  static Future<String> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "message": message,
        "context": {
          "calendar": calendar,
          "tasks": tasks,
        },
        "history": history ?? []
      };

      // 디버깅
      _printDebugData('/chatbot', requestData);

      final response = await http.post(
        Uri.parse('$baseUrl/chatbot'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('챗봇 응답: $data');
        return data['response'] ?? "응답이 없습니다.";
      } else {
        print("서버 오류(챗봇): ${response.statusCode} - ${response.body}");
        return "서버 오류: ${response.statusCode}";
      }
    } catch (e) {
      print("통신 오류(챗봇): $e");
      return "통신 오류: $e";
    }
  }
}