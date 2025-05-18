import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String apiUrl = "http://localhost:5001/analyze"; // AI 서버 주소

  // calendar, todo 리스트를 JSON 형식으로 보내서 AI 분석 결과 받기
  static Future<String> analyzeTasks({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> todo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"calendar": calendar, "todo": todo}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "AI로부터 응답이 없습니다.";
      } else {
        return "서버 오류: ${response.statusCode}";
      }
    } catch (e) {
      return "통신 오류: $e";
    }
  }
}
