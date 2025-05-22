import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 배포된 서버 URL
  static const String baseUrl = 'https://railwavve-production-68d4.up.railway.app';

  // HTTP 헤더 설정
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 1. 일정 생성 API
  static Future<Map<String, dynamic>> createSchedule({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> calendar,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/schedule'),
        headers: headers,
        body: jsonEncode({
          'tasks': tasks,
          'calendar': calendar,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  // 2. AI 조언 받기 API
  static Future<Map<String, dynamic>> getAdvice({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> calendar,
    String? date,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/advice'),
        headers: headers,
        body: jsonEncode({
          'tasks': tasks,
          'calendar': calendar,
          'date': date ?? DateTime.now().toString().split(' ')[0],
          'preferences': preferences ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  // 3. 챗봇 대화 API
  static Future<Map<String, dynamic>> chatWithBot({
    required String message,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chatbot'),
        headers: headers,
        body: jsonEncode({
          'message': message,
          'context': context ?? {},
          'history': history ?? [],
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  // 4. 대시보드 메시지 API
  static Future<Map<String, dynamic>> getDashboardMessage({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> calendar,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dashboard_message'),
        headers: headers,
        body: jsonEncode({
          'tasks': tasks,
          'calendar': calendar,
          'date': date ?? DateTime.now().toString().split(' ')[0],
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  // 5. Gemini API 직접 호출
  static Future<Map<String, dynamic>> callGeminiAPI({
    required String prompt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/gemini'),
        headers: headers,
        body: jsonEncode({
          'prompt': prompt,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  // 6. 예측 모델 API (dodo 기능)
  static Future<Map<String, dynamic>> predict({
    required String input,
    required String start,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: headers,
        body: jsonEncode({
          'input': input,
          'start': start,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }
}