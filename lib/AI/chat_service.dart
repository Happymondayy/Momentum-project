import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class ChatService {
  static String get _apiUrl => 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';
  late final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _apiKey;

  // 일정 추가 상태 관리
  Map<String, dynamic> _schedulingState = {
    'isScheduling': false,
    'step': 0, // 0: 시작, 1: 제목, 2: 날짜, 3: 시간, 4: 완료
    'data': {},
    'type': null, // 'calendar' 또는 'todo'
  };

  // 일정 추천 상태 관리 (새로 추가)
  Map<String, dynamic> _recommendationState = {
    'isRecommending': false,
    'step': 0, // 0: 시작, 1: 활동유형, 2: 시간대, 3: 강도, 4: 특별요청, 5: 완료
    'preferences': {},
    'recommendedSchedule': [],
  };

  ChatService({required this.userId}) {
    _apiKey = "AIzaSyDNfd7f0Bgg0K1d_95HXMMvUXiQ9FqdkRQ";
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final apiKeyDoc = await _firestore.collection('config').doc('api_keys').get();
      final firebaseKey = apiKeyDoc.data()?['gemini_api_key'] ?? '';
      if (firebaseKey.isNotEmpty) {
        _apiKey = firebaseKey;
        print('Firebase에서 API 키 로드 성공');
      }
    } catch (e) {
      print('Firebase API 키 로드 중 오류: $e');
    }
  }

  // 일정 추천 요청 감지 (새로 추가)
  bool _isScheduleRecommendationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return (lowerMessage.contains('추천') || lowerMessage.contains('뭐 해야') ||
        lowerMessage.contains('뭐할까') || lowerMessage.contains('계획') ||
        lowerMessage.contains('일정 만들어') || lowerMessage.contains('하루 계획')) &&
        (lowerMessage.contains('일정') || lowerMessage.contains('계획') ||
            lowerMessage.contains('하루') || lowerMessage.contains('오늘'));
  }

  // 일정 추가 요청 감지
  bool _isScheduleAddRequest(String message) {
    final lowerMessage = message.toLowerCase();
    return (lowerMessage.contains('일정') || lowerMessage.contains('할 일') ||
        lowerMessage.contains('이벤트') || lowerMessage.contains('약속')) &&
        (lowerMessage.contains('추가') || lowerMessage.contains('만들') ||
            lowerMessage.contains('저장') || lowerMessage.contains('등록') ||
            lowerMessage.contains('생성'));
  }

  // 일정 추천 단계별 처리 (새로 추가)
  Map<String, dynamic> _processRecommendationStep(String message, List<Map<String, dynamic>> calendar, List<Map<String, dynamic>> tasks) {
    final step = _recommendationState['step'];

    switch (step) {
      case 0: // 일정 추천 시작
        if (_isScheduleRecommendationRequest(message)) {
          _recommendationState['isRecommending'] = true;
          _recommendationState['step'] = 1;
          _recommendationState['preferences'] = {};

          return {
            "response": "🌟 **맞춤 일정 추천을 시작해볼게요!**\n\n오늘 가장 집중하고 싶은 활동이 무엇인가요?\n\n1️⃣ 공부/학습 📚\n2️⃣ 운동/건강 💪\n3️⃣ 휴식/힐링 😌\n4️⃣ 취미/여가 🎨\n5️⃣ 업무/생산성 💼\n6️⃣ 사회활동/만남 👥\n\n번호나 직접 말씀해주세요! (예: '1번' 또는 '공부에 집중하고 싶어요')",
            "actions": [],
            "isRecommending": true
          };
        }
        break;

      case 1: // 활동 유형 선택
        String activityType = '';
        String activityName = '';
        final lowerInput = message.toLowerCase();

        if (lowerInput.contains('1') || lowerInput.contains('공부') || lowerInput.contains('학습')) {
          activityType = 'study';
          activityName = '공부/학습';
        } else if (lowerInput.contains('2') || lowerInput.contains('운동') || lowerInput.contains('건강')) {
          activityType = 'exercise';
          activityName = '운동/건강';
        } else if (lowerInput.contains('3') || lowerInput.contains('휴식') || lowerInput.contains('힐링')) {
          activityType = 'rest';
          activityName = '휴식/힐링';
        } else if (lowerInput.contains('4') || lowerInput.contains('취미') || lowerInput.contains('여가')) {
          activityType = 'hobby';
          activityName = '취미/여가';
        } else if (lowerInput.contains('5') || lowerInput.contains('업무') || lowerInput.contains('생산성')) {
          activityType = 'work';
          activityName = '업무/생산성';
        } else if (lowerInput.contains('6') || lowerInput.contains('사회') || lowerInput.contains('만남')) {
          activityType = 'social';
          activityName = '사회활동/만남';
        } else {
          return {
            "response": "다시 선택해주세요! 1~6번 중 하나를 선택하거나 원하는 활동을 직접 말씀해주세요.",
            "actions": [],
            "isRecommending": true
          };
        }

        _recommendationState['preferences']['activityType'] = activityType;
        _recommendationState['preferences']['activityName'] = activityName;
        _recommendationState['step'] = 2;

        return {
          "response": "좋아요! **$activityName**에 집중하고 싶으시군요! 🎉\n\n어느 시간대에 활동하는 것을 선호하시나요?\n\n1️⃣ 오전 (9시-12시) ☀️\n2️⃣ 오후 (12시-18시) 🌤️\n3️⃣ 저녁 (18시-21시) 🌆\n4️⃣ 상관없어요 🕐\n\n언제가 가장 집중이 잘 되시나요?",
          "actions": [],
          "isRecommending": true
        };

      case 2: // 시간대 선택
        String timePreference = '';
        String timeName = '';
        final lowerInput = message.toLowerCase();

        if (lowerInput.contains('1') || lowerInput.contains('오전')) {
          timePreference = 'morning';
          timeName = '오전';
        } else if (lowerInput.contains('2') || lowerInput.contains('오후')) {
          timePreference = 'afternoon';
          timeName = '오후';
        } else if (lowerInput.contains('3') || lowerInput.contains('저녁')) {
          timePreference = 'evening';
          timeName = '저녁';
        } else if (lowerInput.contains('4') || lowerInput.contains('상관없어') || lowerInput.contains('언제나')) {
          timePreference = 'all';
          timeName = '언제나';
        } else {
          return {
            "response": "다시 선택해주세요! 1~4번 중 하나를 선택해주세요.",
            "actions": [],
            "isRecommending": true
          };
        }

        _recommendationState['preferences']['timePreference'] = timePreference;
        _recommendationState['preferences']['timeName'] = timeName;
        _recommendationState['step'] = 3;

        return {
          "response": "네! **$timeName 시간대**를 선호하시는군요! 👍\n\n오늘 하루를 어떤 강도로 보내고 싶으신가요?\n\n1️⃣ 여유롭게 (적은 활동, 충분한 휴식) 🐌\n2️⃣ 적당히 (균형잡힌 활동) ⚖️\n3️⃣ 빡빡하게 (많은 활동, 높은 생산성) 🔥\n\n어떤 하루를 원하시나요?",
          "actions": [],
          "isRecommending": true
        };

      case 3: // 강도 선택
        String intensity = '';
        String intensityName = '';
        final lowerInput = message.toLowerCase();

        if (lowerInput.contains('1') || lowerInput.contains('여유')) {
          intensity = 'light';
          intensityName = '여유롭게';
        } else if (lowerInput.contains('2') || lowerInput.contains('적당') || lowerInput.contains('균형')) {
          intensity = 'normal';
          intensityName = '적당히';
        } else if (lowerInput.contains('3') || lowerInput.contains('빡빡') || lowerInput.contains('많이')) {
          intensity = 'intense';
          intensityName = '빡빡하게';
        } else {
          return {
            "response": "다시 선택해주세요! 1~3번 중 하나를 선택해주세요.",
            "actions": [],
            "isRecommending": true
          };
        }

        _recommendationState['preferences']['intensity'] = intensity;
        _recommendationState['preferences']['intensityName'] = intensityName;
        _recommendationState['step'] = 4;

        return {
          "response": "완벽해요! **$intensityName** 하루를 원하시는군요! ✨\n\n특별히 포함하고 싶은 활동이나 피하고 싶은 활동이 있나요?\n\n예시:\n• '명상 시간을 꼭 넣어줘'\n• '회의는 피하고 싶어'\n• '친구와 통화 시간을 넣어줘'\n• '특별한 건 없어'\n\n자유롭게 말씀해주세요!",
          "actions": [],
          "isRecommending": true
        };

      case 4: // 특별 요청 및 최종 추천 생성
        _recommendationState['preferences']['specialRequests'] = message;

        // 최종 추천 일정 생성
        final recommendedSchedule = _generatePersonalizedSchedule(
            _recommendationState['preferences'],
            calendar,
            tasks
        );

        _recommendationState['recommendedSchedule'] = recommendedSchedule;

        String response = "🌟 **완벽한 맞춤 일정이 완성되었어요!**\n\n당신의 선호도를 바탕으로 만든 오늘의 추천 일정입니다:\n\n";

        response += "📋 **선택하신 옵션들:**\n";
        response += "• 활동 유형: ${_recommendationState['preferences']['activityName']}\n";
        response += "• 선호 시간: ${_recommendationState['preferences']['timeName']}\n";
        response += "• 하루 강도: ${_recommendationState['preferences']['intensityName']}\n";
        response += "• 특별 요청: ${message.isEmpty ? '없음' : message}\n\n";

        response += "⏰ **추천 일정:**\n";
        for (int i = 0; i < recommendedSchedule.length; i++) {
          final activity = recommendedSchedule[i];
          response += "${i + 1}. **${activity['time']}** - ${activity['title']}\n";
          response += "   ${activity['description']}\n\n";
        }

        response += "🤔 **이 일정들을 오늘 플래너에 추가하시겠어요?**\n";
        response += "'네' 또는 '추가해줘'라고 답하시면 자동으로 플래너에 추가해드릴게요!\n";
        response += "'다시' 또는 '수정'이라고 하시면 다시 만들어드릴게요!";

        _recommendationState['step'] = 5;

        return {
          "response": response,
          "actions": [],
          "isRecommending": true
        };

      case 5: // 최종 확인 및 적용
        final lowerInput = message.toLowerCase();

        if (lowerInput.contains('네') || lowerInput.contains('추가') ||
            lowerInput.contains('예') || lowerInput.contains('좋아') ||
            lowerInput.contains('응') || lowerInput.contains('맞아')) {

          // 추천된 일정들을 액션으로 반환
          final recommendedSchedule = _recommendationState['recommendedSchedule'] as List<Map<String, dynamic>>;
          List<Map<String, dynamic>> actions = [];

          for (var activity in recommendedSchedule) {
            actions.add({
              "action": "add_task",
              "data": {
                "title": activity['title'],
                "date": DateTime.now().toString().split(' ')[0],
                "time": activity['time'],
                "endTime": activity['endTime'],
                "description": activity['description'],
                "importance": activity['importance'] ?? 3,
                "urgency": activity['urgency'] ?? 3,
                "type": "todo"
              }
            });
          }

          // 상태 초기화
          _recommendationState = {
            'isRecommending': false,
            'step': 0,
            'preferences': {},
            'recommendedSchedule': [],
          };

          return {
            "response": "🎉 **완료!** 추천 일정이 모두 플래너에 추가되었어요!\n\n플래너 화면에서 확인해보세요. 언제든지 수정하거나 삭제할 수 있어요. 좋은 하루 보내세요! 😊",
            "actions": actions,
            "isRecommending": false
          };

        } else if (lowerInput.contains('아니') || lowerInput.contains('싫어') ||
            lowerInput.contains('안 해') || lowerInput.contains('취소')) {

          // 상태 초기화
          _recommendationState = {
            'isRecommending': false,
            'step': 0,
            'preferences': {},
            'recommendedSchedule': [],
          };

          return {
            "response": "알겠어요! 언제든지 새로운 일정 추천이 필요하시면 '일정 추천해줘'라고 말씀해주세요. 다른 도움이 필요하시면 언제든 말씀해주세요! 😊",
            "actions": [],
            "isRecommending": false
          };

        } else if (lowerInput.contains('다시') || lowerInput.contains('수정')) {

          // 처음부터 다시 시작
          _recommendationState = {
            'isRecommending': true,
            'step': 1,
            'preferences': {},
            'recommendedSchedule': [],
          };

          return {
            "response": "🌟 **다시 맞춤 일정 추천을 시작해볼게요!**\n\n오늘 가장 집중하고 싶은 활동이 무엇인가요?\n\n1️⃣ 공부/학습 📚\n2️⃣ 운동/건강 💪\n3️⃣ 휴식/힐링 😌\n4️⃣ 취미/여가 🎨\n5️⃣ 업무/생산성 💼\n6️⃣ 사회활동/만남 👥\n\n번호나 직접 말씀해주세요!",
            "actions": [],
            "isRecommending": true
          };

        } else {
          return {
            "response": "'네' 또는 '아니요'로 답해주세요! 추천된 일정을 플래너에 추가하시겠어요?",
            "actions": [],
            "isRecommending": true
          };
        }

      default:
      // 상태 초기화
        _recommendationState = {
          'isRecommending': false,
          'step': 0,
          'preferences': {},
          'recommendedSchedule': [],
        };
        break;
    }

    return {
      "response": "죄송해요, 다시 처음부터 시작해주세요. '일정 추천해줘'라고 말씀해주시면 도와드릴게요!",
      "actions": [],
      "isRecommending": false
    };
  }

  // 개인화된 일정 생성 함수 (새로 추가)
  List<Map<String, dynamic>> _generatePersonalizedSchedule(
      Map<String, dynamic> preferences,
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
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
    final activities = _getActivityTemplates(preferences['activityType']);

    // 특별 요청 처리
    final specialRequests = preferences['specialRequests']?.toString().toLowerCase() ?? '';
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
    for (int i = 0; i < specialActivities.length && i < freeTimeSlots.length; i++) {
      final activity = specialActivities[i];
      final duration = activity['duration'] ?? 60;
      final endHour = int.parse(freeTimeSlots[i].split(':')[0]);
      final endMinute = int.parse(freeTimeSlots[i].split(':')[1]);
      final totalMinutes = endHour * 60 + endMinute + duration;

      recommendedSchedule.add({
        'title': activity['title'],
        'description': activity['description'],
        'time': freeTimeSlots[i],
        'endTime': '${(totalMinutes ~/ 60).toString().padLeft(2, '0')}:${(totalMinutes % 60).toString().padLeft(2, '0')}',
        'type': preferences['activityType'],
        'importance': activity['importance'] ?? 3,
        'urgency': activity['urgency'] ?? 3,
      });
    }

    // 나머지 활동 추가
    final remainingSlots = freeTimeSlots.skip(specialActivities.length).take(maxActivities - specialActivities.length).toList();

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

  // 빈 시간대 찾기 함수 (새로 추가)
  List<String> _findAvailableTimeSlots(List<Map<String, dynamic>> calendar, String date) {
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

  // 활동 템플릿 가져오기 함수 (새로 추가)
  List<Map<String, dynamic>> _getActivityTemplates(String activityType) {
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

  // 자연어 날짜 파싱
  DateTime? _parseNaturalDate(String input) {
    final now = DateTime.now();
    final lowerInput = input.toLowerCase().trim();

    // 상대적 날짜
    if (lowerInput.contains('오늘')) {
      return DateTime(now.year, now.month, now.day);
    } else if (lowerInput.contains('내일')) {
      return DateTime(now.year, now.month, now.day + 1);
    } else if (lowerInput.contains('모레')) {
      return DateTime(now.year, now.month, now.day + 2);
    }

    // 요일 처리
    final weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

    for (var entry in weekdays.entries) {
      if (lowerInput.contains('${entry.key}요일') || lowerInput.contains(entry.key)) {
        int currentWeekday = now.weekday;
        int targetWeekday = entry.value;
        int daysToAdd;

        if (lowerInput.contains('다음 주') || lowerInput.contains('다음주')) {
          daysToAdd = 7 - currentWeekday + targetWeekday;
        } else {
          daysToAdd = targetWeekday - currentWeekday;
          if (daysToAdd <= 0) daysToAdd += 7;
        }

        return DateTime(now.year, now.month, now.day + daysToAdd);
      }
    }

    // YYYY-MM-DD 형식
    final dateRegex = RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})');
    final dateMatch = dateRegex.firstMatch(input);
    if (dateMatch != null) {
      return DateTime(
          int.parse(dateMatch.group(1)!),
          int.parse(dateMatch.group(2)!),
          int.parse(dateMatch.group(3)!)
      );
    }

    // MM월 DD일 형식
    final koreanDateRegex = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final koreanMatch = koreanDateRegex.firstMatch(input);
    if (koreanMatch != null) {
      return DateTime(
          now.year,
          int.parse(koreanMatch.group(1)!),
          int.parse(koreanMatch.group(2)!)
      );
    }

    // MM/DD 형식
    final shortDateRegex = RegExp(r'(\d{1,2})/(\d{1,2})');
    final shortMatch = shortDateRegex.firstMatch(input);
    if (shortMatch != null) {
      return DateTime(
          now.year,
          int.parse(shortMatch.group(1)!),
          int.parse(shortMatch.group(2)!)
      );
    }

    return null;
  }

  // 자연어 시간 파싱
  Map<String, String>? _parseNaturalTime(String input) {
    final lowerInput = input.toLowerCase().trim();

    // 오전/오후 시간 (예: 오후 3시, 오전 9시 30분)
    final koreanTimeRegex = RegExp(r'(오전|오후)\s*(\d{1,2})시(?:\s*(\d{1,2})분)?');
    final koreanMatch = koreanTimeRegex.firstMatch(lowerInput);

    if (koreanMatch != null) {
      final ampm = koreanMatch.group(1);
      int hour = int.parse(koreanMatch.group(2)!);
      final minute = koreanMatch.group(3) != null ? int.parse(koreanMatch.group(3)!) : 0;

      if (ampm == '오후' && hour < 12) hour += 12;
      if (ampm == '오전' && hour == 12) hour = 0;

      final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final endTime = '${((hour + 1) % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      return {'startTime': startTime, 'endTime': endTime};
    }

    // 24시간 형식 (예: 15시, 14:30)
    final time24Regex = RegExp(r'(\d{1,2}):?(\d{0,2})시?');
    final time24Match = time24Regex.firstMatch(input);

    if (time24Match != null) {
      final hour = int.parse(time24Match.group(1)!);
      final minute = time24Match.group(2)!.isEmpty ? 0 : int.parse(time24Match.group(2)!);

      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        final endTime = '${((hour + 1) % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

        return {'startTime': startTime, 'endTime': endTime};
      }
    }

    return null;
  }

  // 대화형 일정 추가 처리
  Map<String, dynamic> _processSchedulingStep(String message) {
    final step = _schedulingState['step'];

    switch (step) {
      case 0: // 일정 추가 시작
        if (_isScheduleAddRequest(message)) {
          _schedulingState['isScheduling'] = true;
          _schedulingState['step'] = 1;
          _schedulingState['data'] = {};

          return {
            "response": "어떤 일정을 추가하시겠어요? 먼저 일정의 제목을 알려주세요.\n\n예시: '팀 회의', '병원 예약', '친구 만나기'",
            "actions": [],
            "isScheduling": true
          };
        }
        break;

      case 1: // 제목 입력
        _schedulingState['data']['title'] = message.trim();
        _schedulingState['step'] = 2;

        return {
          "response": "\"${message}\" 일정이군요! 언제로 잡을까요?\n\n예시: '내일', '이번 주 금요일', '5월 25일', '오늘'",
          "actions": [],
          "isScheduling": true
        };

      case 2: // 날짜 입력
        final parsedDate = _parseNaturalDate(message);

        if (parsedDate == null) {
          return {
            "response": "날짜를 정확히 알아듣지 못했어요. 다시 말씀해주세요.\n\n예시: '내일', '이번 주 금요일', '5월 25일'",
            "actions": [],
            "isScheduling": true
          };
        }

        _schedulingState['data']['date'] = parsedDate;
        _schedulingState['step'] = 3;

        final dateStr = '${parsedDate.month}월 ${parsedDate.day}일';
        return {
          "response": "${dateStr}로 잡겠습니다! 몇 시에 하시겠어요?\n\n예시: '오후 3시', '오전 10시 30분', '14:00'\n\n(시간을 정하지 않으려면 '시간 없음'이라고 말씀해주세요)",
          "actions": [],
          "isScheduling": true
        };

      case 3: // 시간 입력
        if (message.toLowerCase().contains('시간 없음') ||
            message.toLowerCase().contains('없음') ||
            message.toLowerCase().contains('하루종일')) {
          // 시간 없는 일정
          _schedulingState['data']['startTime'] = null;
          _schedulingState['data']['endTime'] = null;
          _schedulingState['data']['isAllDay'] = true;
        } else {
          final parsedTime = _parseNaturalTime(message);

          if (parsedTime == null) {
            return {
              "response": "시간을 정확히 알아듣지 못했어요. 다시 말씀해주세요.\n\n예시: '오후 3시', '오전 10시 30분', '14:00'\n\n(시간을 정하지 않으려면 '시간 없음'이라고 말씀해주세요)",
              "actions": [],
              "isScheduling": true
            };
          }

          _schedulingState['data']['startTime'] = parsedTime['startTime'];
          _schedulingState['data']['endTime'] = parsedTime['endTime'];
          _schedulingState['data']['isAllDay'] = false;
        }

        // 일정 추가 완료
        final eventData = Map<String, dynamic>.from(_schedulingState['data']);

        // 상태 초기화
        _schedulingState = {
          'isScheduling': false,
          'step': 0,
          'data': {},
          'type': null,
        };

        // 성공 메시지 생성
        final title = eventData['title'];
        final date = eventData['date'] as DateTime;
        final dateStr = '${date.year}년 ${date.month}월 ${date.day}일';

        String timeStr = '';
        if (eventData['isAllDay'] == true) {
          timeStr = ' (하루종일)';
        } else if (eventData['startTime'] != null) {
          final startTime = eventData['startTime'];
          timeStr = ' ${startTime}';
        }

        return {
          "response": "✅ \"${title}\" 일정이 ${dateStr}${timeStr}에 추가되었습니다!\n\n일정이 캘린더에 반영되었어요. 다른 도움이 필요하시면 언제든 말씀해주세요!",
          "actions": [
            {
              "action": "add_task",
              "data": {
                "title": eventData['title'],
                "date": date.toString().split(' ')[0],
                "time": eventData['startTime'],
                "endTime": eventData['endTime'],
                "isAllDay": eventData['isAllDay'] ?? false,
                "type": "calendar"
              }
            }
          ],
          "isScheduling": false
        };

      default:
      // 상태 초기화
        _schedulingState = {
          'isScheduling': false,
          'step': 0,
          'data': {},
          'type': null,
        };
        break;
    }

    return {
      "response": "죄송해요, 다시 처음부터 시작해주세요. '일정 추가해줘'라고 말씀해주시면 도와드릴게요!",
      "actions": [],
      "isScheduling": false
    };
  }

  // 기존 chatWithAssistant 메서드 수정
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> history,
    String? action,
  }) async {
    try {
      // 일정 추천 중인지 확인 (새로 추가된 부분)
      if (_recommendationState['isRecommending'] == true || _isScheduleRecommendationRequest(message)) {
        return _processRecommendationStep(message, calendar, tasks);
      }

      // 일정 추가 중인지 확인
      if (_schedulingState['isScheduling'] == true || _isScheduleAddRequest(message)) {
        return _processSchedulingStep(message);
      }

      // API 키 확인
      if (_apiKey.isEmpty) {
        return generateOfflineResponse(message, calendar, tasks);
      }

      // 현재 날짜 및 시간
      final now = DateTime.now();
      final formattedDate = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

      // 대화 기록 형식화
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

사용자가 "오늘 할 일"이나 "내 일정" 등을 물으면 구체적으로 답변하고, 절대 스스로 생각해보라고 하지 마세요.
항상 친절하고 도움이 되도록 대화하며, 한국어로 응답하세요.
''';

      // 대화 설정
      List<Map<String, dynamic>> conversationContents = [];

      if (formattedHistory.isNotEmpty) {
        conversationContents.addAll(formattedHistory);
      } else {
        conversationContents.add({
          "role": "user",
          "parts": [{"text": "안녕하세요. 도움이 필요합니다."}]
        });

        conversationContents.add({
          "role": "model",
          "parts": [{"text": initialPrompt}]
        });
      }

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

      // API 요청 보내기
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        try {
          final jsonStart = text.indexOf('{');
          final jsonEnd = text.lastIndexOf('}') + 1;

          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonString = text.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> parsedResponse = Map<String, dynamic>.from(json.decode(jsonString));

            if (!parsedResponse.containsKey('actions')) {
              parsedResponse['actions'] = <Map<String, dynamic>>[];
            } else {
              final actions = parsedResponse['actions'];
              if (actions is List) {
                parsedResponse['actions'] = List<Map<String, dynamic>>.from(
                    actions.map((action) => Map<String, dynamic>.from(action))
                );
              }
            }

            return parsedResponse;
          } else {
            return {
              "response": text,
              "actions": <Map<String, dynamic>>[]
            };
          }
        } catch (e) {
          print('JSON 파싱 오류: $e');
          return {
            "response": text,
            "actions": <Map<String, dynamic>>[]
          };
        }
      }

      throw Exception('API 요청 실패: ${response.statusCode}');
    } catch (e) {
      print('AI 응답 처리 중 오류: $e');
      return generateOfflineResponse(message, calendar, tasks);
    }
  }

  // 오프라인 응답 생성 (기존 코드 유지)
  Map<String, dynamic> generateOfflineResponse(String message, [List<Map<String, dynamic>>? calendar, List<Map<String, dynamic>>? tasks]) {
    message = message.toLowerCase();
    final now = DateTime.now();
    final today = "${now.year}-${_padZero(now.month)}-${_padZero(now.day)}";

    Map<String, dynamic> response = {
      "response": "현재 서버 연결이 원활하지 않아 기본 응답만 제공할 수 있습니다. 인터넷 연결을 확인해주세요.",
      "actions": []
    };

    if (message.contains("안녕") || message.contains("반가워")) {
      response["response"] = "안녕하세요! 오늘도 좋은 하루 되세요. (오프라인 모드)";
    }
    else if (message.contains("일정") && message.contains("추가")) {
      response["response"] = "일정을 추가하려면 제목, 날짜, 시간 정보가 필요합니다. 예: '내일 3시에 미팅 일정 추가해줘' (오프라인 모드)";
    }
    else if (message.contains("추천") || message.contains("빈 시간")) {
      response["response"] = "오늘 남은 시간에 할 만한 활동으로 독서, 운동, 또는 계획 세우기를 추천드립니다. (오프라인 모드)";
    }
    else if (message.contains("오늘") &&
        (message.contains("할 일") || message.contains("일정") || message.contains("뭐") ||
            message.contains("해야") || message.contains("브리핑"))) {

      String responseMsg = "오늘의 일정과 할 일을 알려드릴게요.\n\n";

      if (calendar != null && tasks != null) {
        final todayEvents = calendar.where((event) =>
        event['date'] == today ||
            (event['date'] != null && event['date'].toString().startsWith(today))
        ).toList();

        final todayTodos = tasks.where((todo) =>
        todo['date'] == today ||
            (todo['date'] != null && todo['date'].toString().startsWith(today))
        ).toList();

        if (todayEvents.isEmpty && todayTodos.isEmpty) {
          responseMsg = "오늘은 등록된 일정이 없네요. 새로운 일정을 추가하시겠어요?";
        } else {
          if (todayEvents.isNotEmpty) {
            responseMsg += "📅 캘린더 일정:\n";
            for (var event in todayEvents) {
              String timeInfo = "";
              if (event['startTime'] != null) {
                if (event['startTime'] is Map) {
                  final hour = event['startTime']['hour'] ?? 0;
                  final minute = event['startTime']['minute'] ?? 0;
                  timeInfo = " (${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})";
                } else if (event['startTime'] is String && event['startTime'].toString().isNotEmpty) {
                  timeInfo = " (${event['startTime']})";
                }
              }
              responseMsg += "• ${event['title']}$timeInfo\n";
            }
            responseMsg += "\n";
          }

          if (todayTodos.isNotEmpty) {
            responseMsg += "📝 오늘의 할 일:\n";
            int completedCount = 0;

            for (var todo in todayTodos) {
              if (todo['isCompleted'] == true) {
                completedCount++;
              }

              String completedMark = todo['isCompleted'] == true ? "✓ " : "";
              String timeInfo = "";
              if (todo['time'] != null && todo['time'].toString().isNotEmpty) {
                timeInfo = " (${todo['time']})";
              }
              responseMsg += "• $completedMark${todo['title']}$timeInfo\n";
            }

            final completionRate = todayTodos.isEmpty ? 0 : (completedCount / todayTodos.length * 100).round();
            responseMsg += "\n현재 완료율: $completionRate%";
          }
        }
      } else {
        responseMsg = "현재 오프라인 모드에서는 상세한 일정 정보를 제공할 수 없습니다. 인터넷 연결을 확인해주세요.";
      }

      response["response"] = responseMsg;
    }
    else if (message.contains("도움말") || message.contains("어떻게") || message.contains("사용")) {
      response["response"] = "저는 일정 관리와 시간 계획을 도와드리는 AI 비서입니다. 일정 추가, 삭제, 추천 등의 기능을 사용해보세요. (오프라인 모드)";
    }

    return response;
  }

  String _padZero(int num) {
    return num.toString().padLeft(2, '0');
  }
}