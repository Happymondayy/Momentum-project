import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIAdviceService {
// 대신 가능한 URL 목록 정의:
  static final List<String> possibleServerUrls = [
    'http://10.0.2.2:5001',       // 안드로이드 에뮬레이터
    'http://192.168.219.110:5001', // 서버 실제 IP (로컬 네트워크)
    'http://127.0.0.1:5001',      // 로컬호스트
    'http://localhost:5001'       // 로컬호스트 (이름)
  ];

// API 엔드포인트 접미사 정의
  static const String geminiEndpointPath = "/gemini";

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


// Gemini API를 통한 AI 어시스턴트와 대화
  static Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
    String? date,
    String? action,
  }) async {
    try {
      // 사용자 닉네임 가져오기
      final nickname = await getUserNickname();

      // 요청할 데이터 준비
      final requestData = {
        "message": message,
        "calendar": calendar,
        "tasks": tasks,
        "history": history,
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
        "preferences": {}, // 나중에 사용자 설정 추가 가능
        "nickname": nickname,
        "action": action // 선택한 액션 유형 (말풍선 선택 시)
      };

      // 디버깅
      _printDebugData('/gemini', requestData);

      // 각 URL에 시도하기
      Exception? lastException;
      for (final serverUrl in possibleServerUrls) {
        try {
          final geminiEndpoint = "$serverUrl/gemini";
          print('서버 연결 시도: $geminiEndpoint');

          final response = await http.post(
            Uri.parse(geminiEndpoint),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(requestData),
          ).timeout(const Duration(seconds: 5)); // 5초 시간제한 추가

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('Gemini 응답: $data');

            // 기본 응답 구조 확인
            if (!data.containsKey('response')) {
              return {
                "response": "죄송합니다. 서버 응답에 문제가 있습니다. 다시 시도해주세요.",
                "actions": []
              };
            }

            return {
              "response": data['response'],
              "actions": List<Map<String, dynamic>>.from(data['actions'] ?? []),
            };
          } else {
            print("서버 오류($serverUrl): ${response.statusCode} - ${response.body}");
          }
        } catch (e) {
          lastException = e as Exception?;
          print("$serverUrl 연결 시도 실패: $e");
          // 다음 URL 시도를 위해 계속 진행
        }
      }

      // 모든 URL이 실패한 경우
      print("서버 오류(Gemini): 모든 연결 시도 실패. 마지막 오류: $lastException");
      return _getFallbackResponse(message, calendar, tasks);
    } catch (e) {
      print("통신 오류(Gemini): $e");
      return _getFallbackResponse(message, calendar, tasks);
    }
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
        Uri.parse('$possibleServerUrls/recommend_time_slots'),
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
        Uri.parse('$possibleServerUrls/recommend_tasks'),
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
        Uri.parse('$possibleServerUrls/advice'),
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