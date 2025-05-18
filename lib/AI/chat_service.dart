import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // 서버 주소 설정
  static const String baseUrl = 'http://192.168.219.110:5001';

  // 디버깅용 - 데이터 출력
  static void _printDebugData(String endpoint, Map<String, dynamic> data) {
    print('===== 요청 정보 (${endpoint}) =====');
    print('데이터: ${jsonEncode(data)}');
  }

  // 캘린더 및 할일 데이터로 AI 스케줄 생성 요청
  static Future<List<Map<String, dynamic>>> generateSchedule({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "calendar": calendar,
        "tasks": tasks,
      };

      // 디버깅
      _printDebugData('/schedule', requestData);

      final response = await http.post(
        Uri.parse('$baseUrl/schedule'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('스케줄 응답: $data');
        return List<Map<String, dynamic>>.from(data ?? []);
      } else {
        print("서버 오류(스케줄): ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("통신 오류(스케줄): $e");
      return [];
    }
  }

  // 챗봇과 대화
  static Future<String> analyzeTasks({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> todo,
    required String userMessage,
  }) async {
    try {
      // 요청할 데이터 준비
      final requestData = {
        "message": userMessage,
        "context": {
          "calendar": calendar,
          "tasks": todo,
        },
        "history": [] // 기존 대화 내역이 필요한 경우 전달
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
        return data['response'] ?? "AI로부터 응답이 없습니다.";
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