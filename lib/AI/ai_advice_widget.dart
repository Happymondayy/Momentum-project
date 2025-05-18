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
        Uri.parse('$baseUrl/advice'),
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

  // 챗봇 대화 API 호출 - 개선된 버전
  static Future<String> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      // 요청할 데이터 준비 - 데이터 구조 확인 및 수정
      final requestData = {
        "message": message,
        "context": {
          "calendar": _sanitizeCalendarData(calendar),
          "tasks": _sanitizeTaskData(tasks),
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

        // 응답이 없는 경우 기본 메시지 제공
        final responseText = data['response'];
        if (responseText == null || responseText.toString().trim().isEmpty) {
          return _getDefaultChatResponse(message, calendar, tasks);
        }

        return responseText;
      } else {
        print("서버 오류(챗봇): ${response.statusCode} - ${response.body}");
        return _getDefaultChatResponse(message, calendar, tasks);
      }
    } catch (e) {
      print("통신 오류(챗봇): $e");
      return _getDefaultChatResponse(message, calendar, tasks);
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

  // 기본 챗봇 응답 생성 (서버 응답 실패 시)
  static String _getDefaultChatResponse(
      String userMessage,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
    // 간단한 키워드 기반 응답
    final lowerMessage = userMessage.toLowerCase();

    // 일정 관련 질문
    if (lowerMessage.contains('일정') ||
        lowerMessage.contains('스케줄') ||
        lowerMessage.contains('뭐해') ||
        lowerMessage.contains('뭐 해') ||
        lowerMessage.contains('할 일')) {

      if (calendar.isEmpty && tasks.isEmpty) {
        return "오늘은 특별한 일정이나 할 일이 없어요. 휴식을 취하거나 개인 시간을 가지는 것도 좋을 것 같아요. 혹시 새로운 일정이나 할 일을 추가하고 싶으신가요?";
      } else {
        String response = "오늘의 일정을 알려드릴게요.\n\n";

        if (calendar.isNotEmpty) {
          response += "📅 일정:\n";
          for (int i = 0; i < calendar.length && i < 3; i++) {
            final event = calendar[i];
            response += "- ${event['title']}";
            if (event['startTime'] != null) {
              response += " (${event['startTime']})";
            }
            response += "\n";
          }

          if (calendar.length > 3) {
            response += "... 그 외 ${calendar.length - 3}개 일정이 더 있어요.\n";
          }

          response += "\n";
        }

        if (tasks.isNotEmpty) {
          response += "📝 할 일:\n";
          for (int i = 0; i < tasks.length && i < 3; i++) {
            final task = tasks[i];
            response += "- ${task['title']}";
            if (task['dueDate'] != null && task['dueDate'] != '없음' && task['dueDate'].toString().isNotEmpty) {
              response += " (마감: ${task['dueDate']})";
            }
            response += "\n";
          }

          if (tasks.length > 3) {
            response += "... 그 외 ${tasks.length - 3}개 할 일이 더 있어요.\n";
          }
        }

        return response;
      }
    }

    // 시간 관리 조언
    else if (lowerMessage.contains('시간') ||
        lowerMessage.contains('효율') ||
        lowerMessage.contains('조언') ||
        lowerMessage.contains('도움')) {

      return "효율적인 시간 관리를 위한 팁을 알려드릴게요:\n\n"
          "1. 가장 중요하고 긴급한 일부터 처리하세요\n"
          "2. 비슷한 종류의 일은 묶어서 처리하면 효율적이에요\n"
          "3. 큰 작업은 작은 단계로 나누어 진행하세요\n"
          "4. 집중해서 일할 시간과 휴식 시간을 명확히 구분하세요\n"
          "5. 하루를 마무리할 때 내일의 할 일을 미리 계획해두세요\n\n"
          "특정 일정이나 할 일에 대해 더 자세한 조언이 필요하시면 언제든 물어보세요!";
    }

    // 일반적인 인사
    else if (lowerMessage.contains('안녕') ||
        lowerMessage.contains('반가') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('hello')) {

      return "안녕하세요! 오늘의 일정과 할 일 관리를 도와드릴게요. 무엇을 도와드릴까요?";
    }

    // 기본 응답
    else {
      return "말씀해주신 내용에 대해 정확히 이해하지 못했어요. 일정 확인, 할 일 관리, 시간 관리 팁 등에 대해 물어보시면 도움을 드릴 수 있어요!";
    }
  }

  // 맞춤형 조언 메시지 생성 (이벤트 키워드 기반)
  static Future<List<Map<String, dynamic>>> getContextualAdvice({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    // 키워드 기반 맞춤 조언 (API 호출 실패 시 대비)
    final List<Map<String, dynamic>> contextualAdvice = [];

    // 캘린더에서 키워드 기반 조언
    for (final event in calendar) {
      final title = event['title'].toString().toLowerCase();

      // 여행 관련 일정
      if (title.contains('여행') || title.contains('trip')) {
        String destination = '';

        if (title.contains('일본')) destination = '일본';
        else if (title.contains('미국')) destination = '미국';
        else if (title.contains('유럽')) destination = '유럽';
        else if (title.contains('제주')) destination = '제주';
        else if (title.contains('부산')) destination = '부산';

        if (destination.isNotEmpty) {
          contextualAdvice.add({
            "text": "$destination 여행 준비는 잘 되고 있나요? 호텔과 항공권은 예약하셨나요?",
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
        contextualAdvice.add({
          "text": "다가오는 회의 준비는 잘 되고 있나요? 필요한 자료를 미리 준비해두세요!",
          "type": "reminder"
        });
      }

      // 시험 관련 일정
      else if (title.contains('시험') || title.contains('테스트') || title.contains('exam')) {
        contextualAdvice.add({
          "text": "시험 준비는 잘 되고 있나요? 핵심 주제를 중심으로 복습 계획을 세워보세요!",
          "type": "suggestion"
        });
      }

      // 생일 관련 일정
      else if (title.contains('생일') || title.contains('birthday')) {
        contextualAdvice.add({
          "text": "생일 축하 메시지나 선물 준비는 잘 되고 있나요?",
          "type": "reminder"
        });
      }
    }

    // 할 일에서 키워드 기반 조언
    for (final task in tasks) {
      final title = task['title'].toString().toLowerCase();

      // 마감일이 가까운 과제
      if ((title.contains('과제') || title.contains('숙제') || title.contains('assignment')) &&
          task['dueDate'] != null && task['dueDate'] != '없음') {
        contextualAdvice.add({
          "text": "과제 마감일이 다가오고 있어요! 시간 관리에 유의하세요.",
          "type": "alert"
        });
        break;  // 중복 메시지 방지
      }

      // 프로젝트 관련 할 일
      else if (title.contains('프로젝트') || title.contains('project')) {
        contextualAdvice.add({
          "text": "프로젝트 진행 상황을 체크해보세요. 계획대로 진행되고 있나요?",
          "type": "suggestion"
        });
        break;  // 중복 메시지 방지
      }
    }

    // 기본 조언 추가 (맞춤형 조언이 없는 경우)
    if (contextualAdvice.isEmpty) {
      return getAdvice(calendar: calendar, tasks: tasks);
    }

    return contextualAdvice;
  }
}