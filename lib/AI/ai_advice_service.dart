import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIAdviceService {
// 대신 가능한 URL 목록 정의:
  static const List<String> possibleUrls = [
    'https://railwavve-production-68d4.up.railway.app', // 안드로이드 에뮬레이터
    'https://railwavve-production-68d4.up.railway.app/', // 서버 실제 IP (로컬 네트워크)
    'https://railwavve-production-68d4.up.railway.app/', // 로컬호스트
    'https://railwavve-production-68d4.up.railway.app/' // 로컬호스트 (이름)
  ];

// API 엔드포인트 접미사 정의
  static const String geminiEndpointPath = "/gemini";

  static String _apiKey = 'AIzaSyB3Gx-qcHLpyBNsuH4UQ-JKRSDeisoo5-c';

  static String get _apiUrl =>
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';

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
        "text": "일정 분석",
        "action": "analyze_schedule",
        "icon": "analytics"
      },
      {
        "text": "맞춤 일정 추천",
        "action": "interactive_recommendation",
        "icon": "auto_awesome"
      },
      {
        "text": "빈 시간 활용하기",
        "action": "free_time",
        "icon": "time"
      },
      {
        "text": "일정 추가",
        "action": "add_task",
        "icon": "add"
      },
      {
        "text": "일정 삭제",
        "action": "delete_task",
        "icon": "delete"
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

      if (title.contains('공부') || title.contains('학습') ||
          title.contains('study') ||
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
      if (title.contains('여행') || title.contains('trip') ||
          title.contains('vacation')) {
        hasTravelPlan = true;

        // 여행지 추출 시도
        final List<String> destinations = [
          '일본',
          '미국',
          '유럽',
          '제주',
          '부산',
          '서울',
          '대만',
          '홍콩',
          '호주'
        ];
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

  // 대화형 일정 추천 시작
  static Map<String, dynamic> startInteractiveRecommendation({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 일정 간단 분석
    final todayEvents = calendar.where((event) {
      return event['date'] == today ||
          (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    final todayTasks = tasks.where((task) {
      return task['date'] == today ||
          (task['date'] != null && task['date'].startsWith(today));
    }).toList();

    String response = "🎯 **맞춤 일정 추천을 시작해볼게요!**\n\n";

    // 현재 상황 간단 요약
    if (todayEvents.isNotEmpty || todayTasks.isNotEmpty) {
      response +=
      "현재 오늘 일정: ${todayEvents.length}개, 할 일: ${todayTasks.length}개가 있네요.\n\n";
    } else {
      response += "오늘은 비교적 여유로운 하루인 것 같아요!\n\n";
    }

    response += "**첫 번째 질문입니다 🤔**\n\n";
    response += "오늘 가장 집중하고 싶은 활동이 무엇인가요?\n\n";
    response += "1️⃣ 공부/학습 📚\n";
    response += "2️⃣ 운동/건강 💪\n";
    response += "3️⃣ 휴식/힐링 😌\n";
    response += "4️⃣ 취미/여가 🎨\n";
    response += "5️⃣ 업무/생산성 💼\n";
    response += "6️⃣ 사회활동/만남 👥\n\n";
    response += "번호나 직접 말씀해주세요! (예: '1번' 또는 '공부에 집중하고 싶어요')";

    return {
      "response": response,
      "actions": [
        {
          "action": "start_interactive_recommendation",
          "data": {
            "step": 1,
            "totalSteps": 4
          }
        }
      ]
    };
  }

  // 대화형 추천 단계별 처리
  static Map<String, dynamic> processRecommendationStep({
    required int step,
    required String userInput,
    required Map<String, dynamic> collectedData,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) {
    switch (step) {
      case 1:
        return _processActivityTypeStep(userInput, collectedData);
      case 2:
        return _processTimePreferenceStep(userInput, collectedData);
      case 3:
        return _processIntensityStep(userInput, collectedData);
      case 4:
        return _generateFinalRecommendation(
            userInput, collectedData, calendar, tasks);
      default:
        return {
          "response": "오류가 발생했습니다. 다시 시작해주세요.",
          "actions": []
        };
    }
  }

  // 1단계: 활동 유형 처리
  static Map<String, dynamic> _processActivityTypeStep(String userInput,
      Map<String, dynamic> collectedData) {
    String activityType = '';
    String activityName = '';

    final lowerInput = userInput.toLowerCase();

    // 번호로 선택한 경우
    if (lowerInput.contains('1') || lowerInput.contains('공부') ||
        lowerInput.contains('학습')) {
      activityType = 'study';
      activityName = '공부/학습';
    } else if (lowerInput.contains('2') || lowerInput.contains('운동') ||
        lowerInput.contains('건강')) {
      activityType = 'exercise';
      activityName = '운동/건강';
    } else if (lowerInput.contains('3') || lowerInput.contains('휴식') ||
        lowerInput.contains('힐링')) {
      activityType = 'rest';
      activityName = '휴식/힐링';
    } else if (lowerInput.contains('4') || lowerInput.contains('취미') ||
        lowerInput.contains('여가')) {
      activityType = 'hobby';
      activityName = '취미/여가';
    } else if (lowerInput.contains('5') || lowerInput.contains('업무') ||
        lowerInput.contains('생산성')) {
      activityType = 'work';
      activityName = '업무/생산성';
    } else if (lowerInput.contains('6') || lowerInput.contains('사회') ||
        lowerInput.contains('만남')) {
      activityType = 'social';
      activityName = '사회활동/만남';
    } else {
      return {
        "response": "다시 선택해주세요! 1~6번 중 하나를 선택하거나 원하는 활동을 직접 말씀해주세요.",
        "actions": [
          {
            "action": "retry_step",
            "data": {
              "step": 1
            }
          }
        ]
      };
    }

    collectedData['activityType'] = activityType;
    collectedData['activityName'] = activityName;

    String response = "좋아요! **$activityName**에 집중하고 싶으시군요! 🎉\n\n";
    response += "**두 번째 질문입니다 ⏰**\n\n";
    response += "어느 시간대에 활동하는 것을 선호하시나요?\n\n";
    response += "1️⃣ 오전 (9시-12시) ☀️\n";
    response += "2️⃣ 오후 (12시-18시) 🌤️\n";
    response += "3️⃣ 저녁 (18시-21시) 🌆\n";
    response += "4️⃣ 상관없어요 🕐\n\n";
    response += "언제가 가장 집중이 잘 되시나요?";

    return {
      "response": response,
      "actions": [
        {
          "action": "continue_recommendation",
          "data": {
            "step": 2,
            "collectedData": collectedData
          }
        }
      ]
    };
  }

  // 2단계: 시간 선호도 처리
  static Map<String, dynamic> _processTimePreferenceStep(String userInput,
      Map<String, dynamic> collectedData) {
    String timePreference = '';
    String timeName = '';

    final lowerInput = userInput.toLowerCase();

    if (lowerInput.contains('1') || lowerInput.contains('오전')) {
      timePreference = 'morning';
      timeName = '오전';
    } else if (lowerInput.contains('2') || lowerInput.contains('오후')) {
      timePreference = 'afternoon';
      timeName = '오후';
    } else if (lowerInput.contains('3') || lowerInput.contains('저녁')) {
      timePreference = 'evening';
      timeName = '저녁';
    } else if (lowerInput.contains('4') || lowerInput.contains('상관없어') ||
        lowerInput.contains('언제나')) {
      timePreference = 'all';
      timeName = '언제나';
    } else {
      return {
        "response": "다시 선택해주세요! 1~4번 중 하나를 선택해주세요.",
        "actions": [
          {
            "action": "retry_step",
            "data": {
              "step": 2
            }
          }
        ]
      };
    }

    collectedData['timePreference'] = timePreference;
    collectedData['timeName'] = timeName;

    String response = "네! **$timeName 시간대**를 선호하시는군요! 👍\n\n";
    response += "**세 번째 질문입니다 💪**\n\n";
    response += "오늘 하루를 어떤 강도로 보내고 싶으신가요?\n\n";
    response += "1️⃣ 여유롭게 (적은 활동, 충분한 휴식) 🐌\n";
    response += "2️⃣ 적당히 (균형잡힌 활동) ⚖️\n";
    response += "3️⃣ 빡빡하게 (많은 활동, 높은 생산성) 🔥\n\n";
    response += "어떤 하루를 원하시나요?";

    return {
      "response": response,
      "actions": [
        {
          "action": "continue_recommendation",
          "data": {
            "step": 3,
            "collectedData": collectedData
          }
        }
      ]
    };
  }

  // 3단계: 강도 처리
  static Map<String, dynamic> _processIntensityStep(String userInput,
      Map<String, dynamic> collectedData) {
    String intensity = '';
    String intensityName = '';

    final lowerInput = userInput.toLowerCase();

    if (lowerInput.contains('1') || lowerInput.contains('여유')) {
      intensity = 'light';
      intensityName = '여유롭게';
    } else if (lowerInput.contains('2') || lowerInput.contains('적당') ||
        lowerInput.contains('균형')) {
      intensity = 'normal';
      intensityName = '적당히';
    } else if (lowerInput.contains('3') || lowerInput.contains('빡빡') ||
        lowerInput.contains('많이')) {
      intensity = 'intense';
      intensityName = '빡빡하게';
    } else {
      return {
        "response": "다시 선택해주세요! 1~3번 중 하나를 선택해주세요.",
        "actions": [
          {
            "action": "retry_step",
            "data": {
              "step": 3
            }
          }
        ]
      };
    }

    collectedData['intensity'] = intensity;
    collectedData['intensityName'] = intensityName;

    String response = "완벽해요! **$intensityName** 하루를 원하시는군요! ✨\n\n";
    response += "**마지막 질문입니다 🎁**\n\n";
    response += "특별히 포함하고 싶은 활동이나 피하고 싶은 활동이 있나요?\n\n";
    response += "예시:\n";
    response += "• '명상 시간을 꼭 넣어줘'\n";
    response += "• '회의는 피하고 싶어'\n";
    response += "• '친구와 통화 시간을 넣어줘'\n";
    response += "• '특별한 건 없어'\n\n";
    response += "자유롭게 말씀해주세요!";

    return {
      "response": response,
      "actions": [
        {
          "action": "continue_recommendation",
          "data": {
            "step": 4,
            "collectedData": collectedData
          }
        }
      ]
    };
  }

  // 4단계: 최종 추천 생성
  static Map<String, dynamic> _generateFinalRecommendation(String userInput,
      Map<String, dynamic> collectedData,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {
    collectedData['specialRequests'] = userInput;

    // 최종 추천 일정 생성
    final recommendedSchedule = _createPersonalizedScheduleFromData(
        collectedData, calendar, tasks);

    String response = "🌟 **완벽한 맞춤 일정이 완성되었어요!**\n\n";
    response += "당신의 선호도를 바탕으로 만든 오늘의 추천 일정입니다:\n\n";

    response += "📋 **선택하신 옵션들:**\n";
    response += "• 활동 유형: ${collectedData['activityName']}\n";
    response += "• 선호 시간: ${collectedData['timeName']}\n";
    response += "• 하루 강도: ${collectedData['intensityName']}\n";
    response += "• 특별 요청: ${userInput.isEmpty ? '없음' : userInput}\n\n";

    response += "⏰ **추천 일정:**\n";
    for (int i = 0; i < recommendedSchedule.length; i++) {
      final activity = recommendedSchedule[i];
      response += "${i + 1}. **${activity['time']}** - ${activity['title']}\n";
      response += "   ${activity['description']}\n\n";
    }

    response += "🤔 **이 일정들을 오늘 플래너에 추가하시겠어요?**\n";
    response += "'네' 또는 '추가해줘'라고 답하시면 자동으로 플래너에 추가해드릴게요!\n";
    response += "'다시' 또는 '수정'이라고 하시면 다시 만들어드릴게요!";

    return {
      "response": response,
      "actions": [
        {
          "action": "show_final_recommendation",
          "data": {
            "recommendedSchedule": recommendedSchedule,
            "preferences": collectedData
          }
        }
      ]
    };
  }

  // 수집된 데이터로 개인화된 일정 생성
  static List<Map<String, dynamic>> _createPersonalizedScheduleFromData(
      Map<String, dynamic> preferences,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 빈 시간대 찾기
    List<String> freeTimeSlots = _findAvailableTimeSlots(calendar, today);

    // 선호 시간대로 필터링
    final timePreference = preferences['timePreference'];
    if (timePreference != 'all') {
      freeTimeSlots = freeTimeSlots.where((slot) {
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

    // 강도에 따른 활동 수 결정
    int maxActivities;
    switch (preferences['intensity']) {
      case 'light':
        maxActivities = 2;
        break;
      case 'intense':
        maxActivities = min(5, freeTimeSlots.length);
        break;
      default:
        maxActivities = min(3, freeTimeSlots.length);
    }

    // 활동 템플릿 가져오기
    final activities = _getDetailedActivityTemplates(
        preferences['activityType']);

    // 특별 요청 처리
    final specialRequests = preferences['specialRequests']
        ?.toString()
        .toLowerCase() ?? '';
    List<Map<String, dynamic>> specialActivities = [];

    if (specialRequests.contains('명상')) {
      specialActivities.add({
        'title': '명상 시간',
        'description': '마음의 평안을 찾는 명상과 호흡 연습',
        'duration': 30,
        'importance': 3,
        'urgency': 2,
      });
    }

    if (specialRequests.contains('통화') || specialRequests.contains('친구')) {
      specialActivities.add({
        'title': '친구와 통화',
        'description': '소중한 사람들과의 소통 시간',
        'duration': 30,
        'importance': 2,
        'urgency': 2,
      });
    }

    if (specialRequests.contains('산책')) {
      specialActivities.add({
        'title': '산책하기',
        'description': '자연을 느끼며 걷는 힐링 시간',
        'duration': 45,
        'importance': 2,
        'urgency': 1,
      });
    }

    // 최종 일정 생성
    List<Map<String, dynamic>> recommendedSchedule = [];

    // 특별 요청 활동 먼저 추가
    for (int i = 0; i < specialActivities.length &&
        i < freeTimeSlots.length; i++) {
      final activity = specialActivities[i];
      final duration = activity['duration'] ?? 60;
      final endHour = int.parse(freeTimeSlots[i].split(':')[0]);
      final endMinute = int.parse(freeTimeSlots[i].split(':')[1]);
      final totalMinutes = endHour * 60 + endMinute + duration;

      recommendedSchedule.add({
        'title': activity['title'],
        'description': activity['description'],
        'time': freeTimeSlots[i],
        'endTime': '${(totalMinutes ~/ 60).toString().padLeft(
            2, '0')}:${(totalMinutes % 60).toString().padLeft(2, '0')}',
        'type': preferences['activityType'],
        'importance': activity['importance'] ?? 3,
        'urgency': activity['urgency'] ?? 3,
      });
    }

    // 나머지 활동 추가
    final remainingSlots = freeTimeSlots.skip(specialActivities.length).take(
        maxActivities - specialActivities.length).toList();

    for (int i = 0; i < remainingSlots.length; i++) {
      final activity = activities[i % activities.length];
      final endHour = int.parse(remainingSlots[i].split(':')[0]) + 1;

      recommendedSchedule.add({
        'title': activity['title'],
        'description': activity['description'],
        'time': remainingSlots[i],
        'endTime': '${endHour.toString().padLeft(2, '0')}:00',
        'type': preferences['activityType'],
        'importance': activity['importance'] ?? 3,
        'urgency': activity['urgency'] ?? 3,
      });
    }

    return recommendedSchedule;
  }

  // 상세한 활동 템플릿
  static List<Map<String, dynamic>> _getDetailedActivityTemplates(
      String activityType) {
    switch (activityType) {
      case 'study':
        return [
          {
            'title': '핵심 개념 학습',
            'description': '가장 중요한 핵심 개념을 깊이 있게 공부하는 시간',
            'importance': 5,
            'urgency': 4,
          },
          {
            'title': '문제 해결 연습',
            'description': '실전 문제를 풀어보며 실력을 향상시키는 시간',
            'importance': 4,
            'urgency': 4,
          },
          {
            'title': '복습 및 정리',
            'description': '배운 내용을 체계적으로 정리하고 복습하는 시간',
            'importance': 4,
            'urgency': 3,
          },
          {
            'title': '학습 계획 수립',
            'description': '앞으로의 학습 방향과 계획을 세우는 시간',
            'importance': 3,
            'urgency': 3,
          },
        ];
      case 'exercise':
        return [
          {
            'title': '유산소 운동',
            'description': '심폐 기능 향상을 위한 유산소 운동',
            'importance': 4,
            'urgency': 3,
          },
          {
            'title': '근력 운동',
            'description': '근력과 체력 향상을 위한 웨이트 트레이닝',
            'importance': 4,
            'urgency': 3,
          },
          {
            'title': '스트레칭',
            'description': '유연성 향상과 근육 이완을 위한 스트레칭',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '요가 또는 필라테스',
            'description': '몸과 마음의 균형을 위한 요가나 필라테스',
            'importance': 3,
            'urgency': 2,
          },
        ];
      case 'rest':
        return [
          {
            'title': '명상 및 호흡 연습',
            'description': '마음의 평안을 찾는 명상과 깊은 호흡 연습',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '자연 속 산책',
            'description': '자연을 느끼며 걷는 힐링 산책',
            'importance': 3,
            'urgency': 1,
          },
          {
            'title': '음악 감상',
            'description': '좋아하는 음악을 들으며 마음을 치유하는 시간',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '일기 쓰기',
            'description': '하루를 돌아보며 감정을 정리하는 시간',
            'importance': 2,
            'urgency': 1,
          },
        ];
      case 'hobby':
        return [
          {
            'title': '창작 활동',
            'description': '그림, 글쓰기, 만들기 등 창의적인 활동',
            'importance': 3,
            'urgency': 1,
          },
          {
            'title': '독서 시간',
            'description': '좋아하는 책을 읽으며 지식과 감성을 기르는 시간',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '영화/드라마 감상',
            'description': '재미있는 영상 콘텐츠를 즐기는 여가 시간',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '새로운 기술 배우기',
            'description': '관심 있는 새로운 스킬이나 기술을 배워보는 시간',
            'importance': 3,
            'urgency': 2,
          },
        ];
      case 'work':
        return [
          {
            'title': '중요 업무 처리',
            'description': '오늘 반드시 완료해야 할 핵심 업무',
            'importance': 5,
            'urgency': 5,
          },
          {
            'title': '이메일 정리',
            'description': '밀린 이메일을 확인하고 답장하는 시간',
            'importance': 3,
            'urgency': 4,
          },
          {
            'title': '업무 계획 수립',
            'description': '앞으로의 업무 일정과 목표를 계획하는 시간',
            'importance': 4,
            'urgency': 3,
          },
          {
            'title': '스킬 업그레이드',
            'description': '업무 관련 새로운 지식이나 기술을 학습하는 시간',
            'importance': 3,
            'urgency': 2,
          },
        ];
      case 'social':
        return [
          {
            'title': '가족/친구 연락',
            'description': '소중한 사람들과 안부를 나누는 시간',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '네트워킹',
            'description': '새로운 인맥을 만들거나 기존 관계를 발전시키는 시간',
            'importance': 3,
            'urgency': 2,
          },
          {
            'title': '커뮤니티 활동',
            'description': '관심사가 같은 사람들과 함께하는 활동',
            'importance': 2,
            'urgency': 1,
          },
          {
            'title': '봉사 활동',
            'description': '사회에 기여하는 의미 있는 봉사 활동',
            'importance': 2,
            'urgency': 1,
          },
        ];
      default:
        return [
          {
            'title': '개인 시간',
            'description': '나만의 시간을 갖고 하고 싶은 일을 하는 시간',
            'importance': 3,
            'urgency': 2,
          },
        ];
    }
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
        return event['date'] == today ||
            (event['date'] != null && event['date'].startsWith(today));
      }).toList();

      final todayTasks = tasks.where((task) {
        return task['date'] == today ||
            (task['date'] != null && task['date'].startsWith(today));
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
      List<Map<String, dynamic>> todayTasks) {
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
    final completedTasks = todayTasks
        .where((task) => task['isCompleted'] == true)
        .length;
    final totalTasks = todayTasks.length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100)
        .round() : 0;

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
      List<Map<String, dynamic>> todayTasks) {
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

    recommendation +=
    "💬 **답변 예시:** '공부에 집중하고 싶고, 오전에 활동하는 걸 좋아해요. 여유롭게 하고 싶어요!'";

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
    Map<String, dynamic> searchResults = _searchSchedulesByKeyword(
        searchKeyword, calendar, tasks);

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

    final deleteWords = [
      '삭제해줘',
      '삭제해',
      '삭제',
      '지워줘',
      '지워',
      '취소해줘',
      '취소',
      '제거해줘',
      '제거',
      '없애줘',
      '없애'
    ];

    for (String deleteWord in deleteWords) {
      if (message.contains(deleteWord)) {
        // 삭제 키워드 앞의 단어들 추출
        int index = message.indexOf(deleteWord);
        String beforeDelete = message.substring(0, index).trim();

        // 불필요한 단어 제거
        final unnecessaryWords = [
          '일정',
          '할일',
          '할 일',
          '을',
          '를',
          '이',
          '가',
          '의',
          '에',
          '그',
          '그거',
          '저거'
        ];
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
      List<Map<String, dynamic>> tasks) {
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

      response +=
      "${allItems.length}. 📅 캘린더: '${event['title']}' (${event['date']})\n";
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

      response +=
      "${allItems.length}. 📝 투두: '${task['title']}' (${task['date'] ??
          '날짜 없음'})\n";
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
  static Map<String, dynamic> _searchSchedulesByKeyword(String keyword,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {
    List<Map<String, dynamic>> foundItems = [];

    // 캘린더에서 검색
    for (int i = 0; i < calendar.length; i++) {
      final event = calendar[i];
      if (event['title'] != null &&
          event['title'].toString().toLowerCase().contains(
              keyword.toLowerCase())) {
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
          task['title'].toString().toLowerCase().contains(
              keyword.toLowerCase())) {
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
  static Map<String, dynamic> _confirmSingleDeletion(
      Map<String, dynamic> searchResults) {
    final item = searchResults['items'][0];
    final type = item['type'] == 'calendar' ? '캘린더' : '투두리스트';
    final emoji = item['type'] == 'calendar' ? '📅' : '📝';

    String response = "🗑️ **삭제 확인**\n\n";
    response += "다음 일정을 삭제하시겠어요?\n";
    response +=
    "$emoji $type: '${item['title']}' (${item['date'] ?? '날짜 없음'})\n\n";
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
  static Map<String, dynamic> _showMultipleOptionsForDeletion(
      Map<String, dynamic> searchResults) {
    final keyword = searchResults['keyword'];
    final items = searchResults['items'] as List<Map<String, dynamic>>;

    String response = "🔍 **'$keyword'와 관련된 일정이 ${items.length}개 있어요:**\n\n";

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final type = item['type'] == 'calendar' ? '캘린더' : '투두리스트';
      final emoji = item['type'] == 'calendar' ? '📅' : '📝';

      response += "${i + 1}. $emoji $type: '${item['title']}' (${item['date'] ??
          '날짜 없음'})\n";
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
    List<Map<String,
        dynamic>> recommendedSchedule = _generateRecommendedActivities(
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
  static List<String> _findAvailableTimeSlots(
      List<Map<String, dynamic>> calendar, String date) {
    final busySlots = <String>[];

    // 기존 일정의 시간대 수집
    final todayEvents = calendar.where((event) =>
    event['date'] == date ||
        (event['date'] != null && event['date'].startsWith(date))
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
      List<Map<String, dynamic>> tasks) {
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

  static Map<String, dynamic> _generateTodayScheduleResponse(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 일정 필터링
    final todayEvents = calendar.where((event) {
      return event['date'] == today ||
          (event['date'] != null && event['date'].startsWith(today));
    }).toList();

    // 오늘 할 일 필터링
    final todayTasks = tasks.where((task) {
      return task['date'] == today ||
          (task['date'] != null && task['date'].startsWith(today));
    }).toList();

    // 응답 생성
    String response = "📅 **오늘 일정을 알려드릴게요**\n\n";

    if (todayEvents.isEmpty && todayTasks.isEmpty) {
      response += "오늘은 등록된 일정이나 할 일이 없네요! 여유로운 하루를 보내세요 ✨\n\n";
      response += "새로운 일정을 추가하거나 맞춤 추천을 받아보시는 건 어떨까요?";
    } else {
      if (todayEvents.isNotEmpty) {
        response += "🗓️ **오늘의 일정 (${todayEvents.length}개):**\n";

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

          response += "${i+1}. **${event['title']}**${timeInfo.isNotEmpty ? ' ($timeInfo)' : ''}";

          if (event['location'] != null && event['location'].toString().isNotEmpty) {
            response += " 📍 ${event['location']}";
          }

          response += "\n";
        }

        if (todayTasks.isNotEmpty) {
          response += "\n";
        }
      }

      if (todayTasks.isNotEmpty) {
        final completedTasks = todayTasks.where((task) => task['isCompleted'] == true).length;
        response += "📝 **오늘의 할 일 (${completedTasks}/${todayTasks.length} 완료):**\n";

        // 먼저 미완료 항목
        final incompleteTasks = todayTasks.where((task) => task['isCompleted'] != true).toList();
        for (int i = 0; i < incompleteTasks.length; i++) {
          final task = incompleteTasks[i];
          response += "${i+1}. ⭕ **${task['title']}**";

          if (task['importance'] != null || task['urgency'] != null) {
            response += " (중요도: ${task['importance'] ?? 1}, 긴급도: ${task['urgency'] ?? 1})";
          }

          response += "\n";
        }

        // 완료된 항목
        final completedTasksList = todayTasks.where((task) => task['isCompleted'] == true).toList();
        for (int i = 0; i < completedTasksList.length; i++) {
          final task = completedTasksList[i];
          response += "${incompleteTasks.length + i + 1}. ✅ ~~${task['title']}~~\n";
        }
      }

      response += "\n💡 **더 효율적인 하루를 위해 맞춤 추천을 받아보세요!**";
    }

    return {
      "response": response,
      "actions": generateRecommendationOptions(calendar, tasks)
    };
  }

// 시간 추천 응답 생성
  Future<Map<String, dynamic>> _generateTimeRecommendationResponse(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) async {
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    // 오늘 일정 필터링
    final todayEvents = calendar.where((event) {
      return event['date'] == today ||
          (event['date'] != null && event['date'].startsWith(today));
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
      response =
      "오늘은 9시부터 21시까지 모든 시간대가 채워져 있네요. 내일 일정을 계획해보는 것은 어떨까요? 아니면 밤이나 새벽 시간대를 활용하실 수도 있습니다.";
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

        response +=
        "🕒 ${slot['time']} ~ ${slot['endTime']}: $activitySuggestion\n\n";

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
        "date": date ?? DateTime.now().toString().split(' ')[0],
        // YYYY-MM-DD 형식
        "minDurationMinutes": minDurationMinutes ?? 30,
        // 기본 30분 단위로 빈 시간 찾기
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

        if (data['recommendations'] == null ||
            (data['recommendations'] as List).isEmpty) {
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
        "date": date ?? DateTime.now().toString().split(' ')[0],
        // YYYY-MM-DD 형식
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

        if (data['recommendations'] == null ||
            (data['recommendations'] as List).isEmpty) {
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
      "09:00",
      "10:00",
      "11:00",
      "12:00",
      "13:00",
      "14:00",
      "15:00",
      "16:00",
      "17:00"
    ];

    // 이미 예약된 시간대 확인
    final List<String> bookedTimeSlots = [];
    for (var event in calendar) {
      if (event.containsKey('startTime') && event['startTime'] != null) {
        String startTime = event['startTime'].toString();
        // 시간만 추출 (HH:mm 형식)
        if (startTime.contains(':')) {
          bookedTimeSlots.add(startTime
              .split(':')
              .first
              .padLeft(2, '0') + ":00");
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
        "text": "오늘 ${freeTimeSlots
            .first}부터 약 1시간 정도 비어있네요. 중요한 일을 처리하기 좋은 시간입니다.",
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
    (task['importance'] != null &&
        int.parse(task['importance'].toString()) >= 3) &&
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
    final todayEvents = calendar
        .where((event) => event['date'] == today)
        .toList();

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
    } else if (todayEvents.isEmpty &&
        (importantTasks.isEmpty || importantTasks.length < 2)) {
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
        "date": date ?? DateTime.now().toString().split(' ')[0],
        // YYYY-MM-DD 형식
        "preferences": {}
        // 나중에 사용자 설정 추가 가능
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
  static List<Map<String, dynamic>> _sanitizeCalendarData(
      List<Map<String, dynamic>> calendar) {
    return calendar.map((event) {
      // 필수 필드 확인 및 변환
      final Map<String, dynamic> sanitizedEvent = {
        "id": event["id"] ?? "cal_${DateTime
            .now()
            .millisecondsSinceEpoch}",
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
  static List<Map<String, dynamic>> _sanitizeTaskData(
      List<Map<String, dynamic>> tasks) {
    return tasks.map((task) {
      // 필수 필드 확인 및 변환
      final Map<String, dynamic> sanitizedTask = {
        "id": task["id"] ?? "task_${DateTime
            .now()
            .millisecondsSinceEpoch}",
        "title": task["title"] ?? "무제 할 일",
      };

      // 선택적 필드 추가
      if (task.containsKey("dueDate")) {
        sanitizedTask["dueDate"] = task["dueDate"];
      }

      if (task.containsKey("importance")) {
        sanitizedTask["importance"] = task["importance"];
      } else {
        sanitizedTask["importance"] = "1"; // 기본값 설정
      }

      if (task.containsKey("urgency")) {
        sanitizedTask["urgency"] = task["urgency"];
      } else {
        sanitizedTask["urgency"] = "1"; // 기본값 설정
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
      List<Map<String, dynamic>> tasks) {
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
      final tomorrow = DateTime.now().add(Duration(days: 1)).toString().split(
          ' ')[0];
      final tomorrowEvents = calendar.where((event) =>
      event["date"] == tomorrow).toList();

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

        final difference = eventDate
            .difference(now)
            .inDays;
        return difference > 0 && difference <= 7;
      }).toList();

      // 여행 관련 일정 찾기
      final travelEvents = upcomingEvents.where((event) {
        final title = event["title"]?.toString().toLowerCase() ?? "";
        return title.contains('여행') || title.contains('trip') ||
            title.contains('vacation');
      }).toList();

      if (travelEvents.isNotEmpty) {
        final travelEvent = travelEvents.first;
        final title = travelEvent["title"] ?? "";
        final dateStr = travelEvent["date"] as String?;
        final eventDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        String daysLeft = "";
        if (eventDate != null) {
          final difference = eventDate
              .difference(now)
              .inDays;
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
        return title.contains('시험') || title.contains('테스트') ||
            title.contains('exam') || title.contains('test');
      }).toList();

      if (examEvents.isNotEmpty) {
        final examEvent = examEvents.first;
        final title = examEvent["title"] ?? "";
        final dateStr = examEvent["date"] as String?;
        final eventDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

        String daysLeft = "";
        if (eventDate != null) {
          final difference = eventDate
              .difference(now)
              .inDays;
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
      final completedTasks = tasks
          .where((task) => task["isCompleted"] == true)
          .length;
      final totalTasks = tasks.length;

      if (completedTasks > 0) {
        defaultMessages.add({
          "text": "오늘 ${completedTasks}/${totalTasks} 할 일을 완료했어요! 정말 잘하고 있어요!",
          "type": "encouragement"
        });
      } else {
        defaultMessages.add({
          "text": "아직 완료한 할 일이 없네요. 하나씩 차근차근 해보세요!",
          "type": "encouragement"
        });
      }

      // 중요도가 높은 미완료 작업 확인
      final importantIncompleteTasks = tasks.where((task) {
        final isCompleted = task["isCompleted"] == true;
        final importance = int.tryParse(
            task["importance"]?.toString() ?? "1") ?? 1;
        return !isCompleted && importance >= 4;
      }).toList();

      if (importantIncompleteTasks.isNotEmpty) {
        final task = importantIncompleteTasks.first;
        defaultMessages.add({
          "text": "중요한 할 일 '${task['title']}'가 아직 미완료예요. 우선적으로 처리해보는 건 어떨까요?",
          "type": "reminder"
        });
      }

      // 긴급도가 높은 미완료 작업 확인
      final urgentIncompleteTasks = tasks.where((task) {
        final isCompleted = task["isCompleted"] == true;
        final urgency = int.tryParse(task["urgency"]?.toString() ?? "1") ?? 1;
        return !isCompleted && urgency >= 4;
      }).toList();

      if (urgentIncompleteTasks.isNotEmpty) {
        final task = urgentIncompleteTasks.first;
        defaultMessages.add({
          "text": "긴급한 할 일 '${task['title']}'가 있어요. 빨리 처리하시는 게 좋겠어요!",
          "type": "warning"
        });
      }
    }

    // 일반적인 조언 메시지 (데이터가 없는 경우)
    if (defaultMessages.isEmpty) {
      final currentHour = DateTime
          .now()
          .hour;

      if (currentHour >= 6 && currentHour < 12) {
        defaultMessages.add({
          "text": "좋은 아침이에요! 오늘 하루도 화이팅하세요. 목표를 세우고 차근차근 실행해보아요!",
          "type": "greeting"
        });
      } else if (currentHour >= 12 && currentHour < 18) {
        defaultMessages.add({
          "text": "오후 시간이에요. 지금까지 잘 해오고 있어요. 잠깐 휴식을 취하고 다시 시작해보세요!",
          "type": "encouragement"
        });
      } else if (currentHour >= 18 && currentHour < 22) {
        defaultMessages.add({
          "text": "하루 수고 많으셨어요! 오늘 있었던 일들을 정리하고 내일을 준비해보는 시간은 어떨까요?",
          "type": "reflection"
        });
      } else {
        defaultMessages.add({
          "text": "늦은 시간이네요. 충분한 휴식을 취하시고 좋은 꿈 꾸세요!",
          "type": "care"
        });
      }
    }

    return defaultMessages;
  }

  // 폴백 응답 - 기본 응답 생성
  static Map<String, dynamic> _getFallbackResponse(String message,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks) {
    final lowerMessage = message.toLowerCase();

    // 인사 관련
    if (lowerMessage.contains('안녕') || lowerMessage.contains('hello') ||
        lowerMessage.contains('hi')) {
      return {
        "response": "안녕하세요! 오늘 하루 일정 관리를 도와드릴게요. 무엇을 도와드릴까요?",
        "actions": generateRecommendationOptions(calendar, tasks)
      };
    }

    // 감사 인사
    if (lowerMessage.contains('고마워') || lowerMessage.contains('감사') ||
        lowerMessage.contains('thank')) {
      return {
        "response": "천만에요! 언제든지 일정 관리가 필요하시면 말씀해주세요. 더 도와드릴 일이 있나요?",
        "actions": generateRecommendationOptions(calendar, tasks)
      };
    }

    // 도움 요청
    if (lowerMessage.contains('도움') || lowerMessage.contains('help')) {
      return {
        "response": "네! 일정 관리를 도와드릴게요.\n\n다음과 같은 기능들을 사용하실 수 있어요:\n• 오늘 일정 확인\n• 맞춤 일정 추천\n• 빈 시간 찾기\n• 일정 추가/삭제\n• 할 일 관리\n\n무엇을 도와드릴까요?",
        "actions": generateRecommendationOptions(calendar, tasks)
      };
    }

    // 오늘 일정 관련
    if (lowerMessage.contains('오늘') &&
        (lowerMessage.contains('일정') || lowerMessage.contains('schedule'))) {
      return _generateTodayScheduleResponse(calendar, tasks);
    }

    // 추천 관련
    if (lowerMessage.contains('추천') || lowerMessage.contains('뭐 해야') ||
        lowerMessage.contains('suggest')) {
      return {
        "response": "맞춤 일정을 추천해드릴게요! 몇 가지 질문에 답해주시면 더 정확한 추천을 해드릴 수 있어요.",
        "actions": [
          {
            "action": "start_interactive_recommendation",
            "data": {
              "step": 1,
              "totalSteps": 4
            }
          }
        ]
      };
    }

    // 빈 시간 관련
    if (lowerMessage.contains('빈 시간') || lowerMessage.contains('여유') ||
        lowerMessage.contains('free time')) {
      return {
        "response": "빈 시간을 찾아드릴게요! 잠시만 기다려주세요.",
        "actions": [
          {
            "action": "find_free_time",
            "data": {
              "date": DateTime.now().toString().split(' ')[0]
            }
          }
        ]
      };
    }

    // 기분/컨디션 관련
    if (lowerMessage.contains('피곤') || lowerMessage.contains('힘들어') ||
        lowerMessage.contains('tired')) {
      return {
        "response": "많이 피곤하시군요. 오늘은 무리하지 마시고 충분한 휴식을 취하는 게 어떨까요? 간단한 휴식 활동을 추천해드릴게요.",
        "actions": [
          {
            "action": "recommend_rest_activities",
            "data": {
              "mood": "tired"
            }
          }
        ]
      };
    }

    if (lowerMessage.contains('기분 좋') || lowerMessage.contains('행복') ||
        lowerMessage.contains('happy')) {
      return {
        "response": "기분이 좋으시다니 저도 기뻐요! 이런 좋은 기분일 때 새로운 도전을 해보는 건 어떨까요?",
        "actions": [
          {
            "action": "recommend_productive_activities",
            "data": {
              "mood": "happy"
            }
          }
        ]
      };
    }

    // 집중 관련
    if (lowerMessage.contains('집중') || lowerMessage.contains('focus')) {
      return {
        "response": "집중이 필요한 시간이군요! 집중력 향상을 위한 일정을 추천해드릴게요.",
        "actions": [
          {
            "action": "recommend_focus_activities",
            "data": {
              "type": "focus"
            }
          }
        ]
      };
    }

    // 운동 관련
    if (lowerMessage.contains('운동') || lowerMessage.contains('헬스') ||
        lowerMessage.contains('exercise')) {
      return {
        "response": "운동 계획을 세우고 싶으시군요! 어떤 종류의 운동을 선호하시나요?",
        "actions": [
          {
            "action": "recommend_exercise",
            "data": {
              "type": "exercise"
            }
          }
        ]
      };
    }

    // 공부 관련
    if (lowerMessage.contains('공부') || lowerMessage.contains('학습') ||
        lowerMessage.contains('study')) {
      return {
        "response": "공부 계획을 도와드릴게요! 효율적인 학습 스케줄을 만들어보세요.",
        "actions": [
          {
            "action": "recommend_study_plan",
            "data": {
              "type": "study"
            }
          }
        ]
      };
    }

    // 기본 응답
    return {
      "response": "죄송해요, 정확히 이해하지 못했어요. 다시 한 번 말씀해주시거나 다음 중에서 선택해주세요:",
      "actions": generateRecommendationOptions(calendar, tasks)
    };
  }
}
