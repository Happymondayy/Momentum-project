import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// AIAdviceWidget 클래스를 실제 위젯으로 변환
class AIAdviceWidget extends StatefulWidget {
  final List<Map<String, dynamic>> calendar;
  final List<Map<String, dynamic>> tasks;
  final String userId;

  const AIAdviceWidget({
    Key? key,
    required this.calendar,
    required this.tasks,
    required this.userId,
  }) : super(key: key);

  @override
  _AIAdviceWidgetState createState() => _AIAdviceWidgetState();
}

class _AIAdviceWidgetState extends State<AIAdviceWidget> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  // 서버 주소는 환경에 맞게 변경 필요
  static const String baseUrl = "http://127.0.0.1:5001"; // Flask 서버 주소

  @override
  void initState() {
    super.initState();
    _loadDashboardMessages();
  }

  @override
  void didUpdateWidget(AIAdviceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendar != widget.calendar || oldWidget.tasks != widget.tasks) {
      _loadDashboardMessages();
    }
  }

  // 맞춤형 대시보드 메시지 로드
  Future<void> _loadDashboardMessages() async {
    setState(() {
      isLoading = true;
    });

    try {
      final messages = await getPersonalizedDashboardMessages(
        calendar: widget.calendar,
        tasks: widget.tasks,
      );

      setState(() {
        this.messages = messages;
        isLoading = false;
      });
    } catch (e) {
      print("메시지 로드 오류: $e");
      setState(() {
        messages = [
          {
            "text": "오늘 하루도 화이팅하세요! 효율적인 시간 관리가 성공의 열쇠입니다.",
            "type": "inspiration"
          }
        ];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D8CFF)),
        ),
      )
          : Column(
        children: [
          for (var message in messages.take(2))
            _buildMessageBubble(message),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    // 메시지 유형에 따른 색상 지정
    Color bubbleColor;
    IconData? iconData;

    switch (message['type']) {
      case 'reminder':
        bubbleColor = Colors.blue.shade100;
        iconData = Icons.event_note;
        break;
      case 'alert':
        bubbleColor = Colors.orange.shade100;
        iconData = Icons.warning_amber;
        break;
      case 'suggestion':
        bubbleColor = Colors.green.shade100;
        iconData = Icons.lightbulb_outline;
        break;
      case 'encouragement':
        bubbleColor = Colors.purple.shade100;
        iconData = Icons.favorite;
        break;
      default:
        bubbleColor = Colors.grey.shade100;
        iconData = Icons.chat_bubble_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: Colors.white,
              size: 20,
            ),
          ),

          // 메시지 내용
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message['text'],
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 디버깅용 - 데이터 출력
  void _printDebugData(String endpoint, Map<String, dynamic> data) {
    print('===== 요청 정보 (${endpoint}) =====');
    print('데이터: ${jsonEncode(data)}');
  }

  // 대시보드 메시지 가져오기
  Future<List<Map<String, dynamic>>> getDashboardMessages({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
  }) async {
    try {
      final requestData = {
        "calendar": _sanitizeCalendarData(calendar),
        "tasks": _sanitizeTaskData(tasks),
        "date": date ?? DateTime.now().toString().split(' ')[0], // YYYY-MM-DD 형식
      };

      _printDebugData('/dashboard_message', requestData);

      final response = await http.post(
        Uri.parse('$baseUrl/dashboard_message'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('대시보드 메시지 응답: $data');

        if (data['messages'] == null || (data['messages'] as List).isEmpty) {
          // API 응답이 없는 경우 맞춤형 메시지 생성
          return await getContextualAdvice(calendar: calendar, tasks: tasks);
        }

        return List<Map<String, dynamic>>.from(data['messages']);
      } else {
        print("서버 오류(대시보드): ${response.statusCode} - ${response.body}");
        return await getContextualAdvice(calendar: calendar, tasks: tasks);
      }
    } catch (e) {
      print("통신 오류(대시보드): $e");
      return await getContextualAdvice(calendar: calendar, tasks: tasks);
    }
  }

  // 조언 받기 API 호출
  Future<List<Map<String, dynamic>>> getAdvice({
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

  // 맞춤형 조언 메시지 생성 (이벤트 키워드 기반)
  Future<List<Map<String, dynamic>>> getContextualAdvice({
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

  // 캘린더 데이터 정제 - 서버에서 기대하는 형식으로 변환
  List<Map<String, dynamic>> _sanitizeCalendarData(List<Map<String, dynamic>> calendar) {
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
  List<Map<String, dynamic>> _sanitizeTaskData(List<Map<String, dynamic>> tasks) {
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
  List<Map<String, dynamic>> _getDefaultAdvice(
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

  // 키워드 기반 맞춤형 조언 생성 함수
  List<Map<String, dynamic>> _generateKeywordBasedAdvice(
      List<Map<String, dynamic>> calendar,
      List<Map<String, dynamic>> tasks
      ) {
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

    // 조언이 없으면 기본 조언 사용
    if (contextualAdvice.isEmpty) {
      return _getDefaultAdvice(calendar, tasks);
    }

    return contextualAdvice;
  }

  // 대시보드 맞춤 메시지 생성 (플래너 말풍선용)
  Future<List<Map<String, dynamic>>> getPersonalizedDashboardMessages({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
  }) async {
    // 기존 대시보드 메시지 API 호출
    final messages = await getDashboardMessages(calendar: calendar, tasks: tasks);

    // 키워드 기반 맞춤형 메시지 강화
    final personalizedMessages = <Map<String, dynamic>>[];

    // 일정에서 특별한 키워드 추출 및 맞춤형 메시지 생성
    for (final event in calendar) {
      final title = event['title'].toString().toLowerCase();
      final date = event['date'];

      // 날짜 형식 변환
      DateTime? eventDate;
      try {
        if (date is String && date.isNotEmpty) {
          eventDate = DateTime.parse(date);
        }
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }

      // 현재 날짜와의 차이 계산
      final today = DateTime.now();
      final difference = eventDate != null
          ? eventDate.difference(today).inDays
          : null;

      // 특정 일정에 대한 맞춤형 메시지 생성
      // 여행 관련
      if ((title.contains('여행') || title.contains('trip')) &&
          difference != null && difference > 0 && difference <= 14) {
        String destination = '';
        if (title.contains('일본')) destination = '일본';
        else if (title.contains('미국')) destination = '미국';
        else if (title.contains('유럽')) destination = '유럽';
        else if (title.contains('제주')) destination = '제주';
        else if (title.contains('부산')) destination = '부산';
        else destination = title.split(' ')[0]; // 첫 단어를 목적지로 추정

        if (destination.isNotEmpty) {
          final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
          personalizedMessages.add({
            "text": "$daysLeft $destination 여행을 가시는군요! 호텔과 항공권은 예약하셨나요?",
            "type": "reminder"
          });

          // 여행 준비물 관련 메시지
          if (difference <= 3) {
            personalizedMessages.add({
              "text": "여행 준비물을 다 챙기셨나요? 여권, 충전기, 필수 약품 등을 확인해보세요.",
              "type": "suggestion"
            });
          }
        }
      }

      // 시험 관련
      else if ((title.contains('시험') || title.contains('테스트') || title.contains('exam')) &&
          difference != null && difference >= -1 && difference <= 7) {
        // 시험 종류 파악 시도
        String examType = '';
        if (title.contains('모의고사')) examType = '모의고사';
        else if (title.contains('중간')) examType = '중간고사';
        else if (title.contains('기말')) examType = '기말고사';
        else if (title.contains('수능')) examType = '수능';
        else if (title.contains('토익')) examType = '토익';
        else if (title.contains('토플')) examType = '토플';

        if (examType.isNotEmpty) {
          final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
          personalizedMessages.add({
            "text": "$daysLeft $examType 시험이 있네요. 준비는 잘 되어가고 있나요? 어떤 과목을 중점적으로 공부하실 계획인가요?",
            "type": "suggestion"
          });
        } else {
          final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
          personalizedMessages.add({
            "text": "$daysLeft 시험이 있어요. 공부 계획은 세우셨나요? 중요한 주제부터 복습하는 것이 효과적입니다.",
            "type": "reminder"
          });
        }
      }

      // 회의/미팅 관련
      else if ((title.contains('회의') || title.contains('미팅') || title.contains('meeting')) &&
          difference != null && difference >= -1 && difference <= 3) {
        final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
        personalizedMessages.add({
          "text": "$daysLeft ${title} 일정이 있습니다. 필요한 자료는 준비되셨나요? 미리 준비하면 회의가 더 효율적으로 진행됩니다.",
          "type": "reminder"
        });
      }

      // 발표 관련
      else if ((title.contains('발표') || title.contains('프레젠테이션') || title.contains('presentation')) &&
          difference != null && difference >= 0 && difference <= 7) {
        final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
        personalizedMessages.add({
          "text": "$daysLeft 발표가 예정되어 있어요. 발표 자료와 대본 준비는 잘 되어가고 있나요?",
          "type": "reminder"
        });
      }

      // 생일/기념일 관련
      else if ((title.contains('생일') || title.contains('기념일') || title.contains('anniversary')) &&
          difference != null && difference >= 0 && difference <= 7) {
        final daysLeft = difference == 0 ? '오늘' : '$difference일 후';
        String person = '';

        // 이름 추출 시도
        final words = title.split(' ');
        if (words.length > 1) {
          // "OO의 생일" 형태에서 OO 추출
          for (int i = 0; i < words.length - 1; i++) {
            if (words[i+1].contains('생일') || words[i+1].contains('기념일')) {
              person = words[i].replaceAll('의', '');
              break;
            }
          }
        }

        if (person.isNotEmpty) {
          personalizedMessages.add({
            "text": "$daysLeft ${person}의 특별한 날이에요! 선물이나 축하 메시지를 준비하셨나요?",
            "type": "reminder"
          });
        } else {
          personalizedMessages.add({
            "text": "$daysLeft 특별한 날이 있어요! 어떻게 기념할 계획인가요?",
            "type": "reminder"
          });
        }
      }
    }

    // 할 일에서 특별한 키워드 추출 및 맞춤형 메시지 생성
    for (final task in tasks) {
      final title = task['title'].toString().toLowerCase();
      final dueDate = task['dueDate'];
      final isCompleted = task['isCompleted'] == true;

      // 완료된 할 일은 건너뛰기
      if (isCompleted) continue;

      // 날짜 형식 변환
      DateTime? taskDueDate;
      try {
        if (dueDate is String && dueDate.isNotEmpty && dueDate != '없음') {
          taskDueDate = DateTime.parse(dueDate);
        }
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }

      // 현재 날짜와의 차이 계산
      final today = DateTime.now();
      final difference = taskDueDate != null
          ? taskDueDate.difference(today).inDays
          : null;

      // 마감일이 임박한 과제/할 일
      if (difference != null && difference >= -1 && difference <= 3) {
        // 과제 관련
        if (title.contains('과제') || title.contains('숙제') || title.contains('assignment')) {
          final daysLeft = difference <= 0 ? '오늘까지' : '$difference일 남았어요';

          String subject = '';
          final words = title.split(' ');
          // 과목명 추출 시도
          if (words.length > 1) {
            for (String word in words) {
              if (!word.contains('과제') && !word.contains('숙제') && !word.contains('assignment')) {
                subject = word;
                break;
              }
            }
          }

          if (subject.isNotEmpty) {
            personalizedMessages.add({
              "text": "$subject 과제가 $daysLeft. 진행 상황은 어떤가요? 도움이 필요하신 부분이 있으신가요?",
              "type": "alert"
            });
          } else {
            personalizedMessages.add({
              "text": "과제 마감이 $daysLeft. 아직 완료하지 않으셨다면 우선순위를 높게 설정하세요.",
              "type": "alert"
            });
          }
        }
        // 프로젝트 관련
        else if (title.contains('프로젝트') || title.contains('project')) {
          final daysLeft = difference <= 0 ? '오늘까지' : '$difference일 남았어요';
          personalizedMessages.add({
            "text": "프로젝트 마감이 $daysLeft. 진행 상황을 점검하고 남은 작업에 집중하세요.",
            "type": "alert"
          });
        }
        // 운동 관련
        else if (title.contains('운동') || title.contains('workout') || title.contains('exercise')) {
          personalizedMessages.add({
            "text": "오늘의 운동 계획을 세우셨나요? 규칙적인 운동은 생산성 향상에도 도움이 됩니다.",
            "type": "suggestion"
          });
        }
        // 독서 관련
        else if (title.contains('독서') || title.contains('책') || title.contains('reading')) {
          personalizedMessages.add({
            "text": "독서 시간을 가지실 계획이군요. 어떤 책을 읽고 계신가요?",
            "type": "suggestion"
          });
        }
        // 일반적인 중요 할 일
        else {
          final urgency = task['urgency'] != null ? int.tryParse(task['urgency'].toString()) ?? 1 : 1;
          final importance = task['importance'] != null ? int.tryParse(task['importance'].toString()) ?? 1 : 1;

          if (urgency >= 4 || importance >= 4) {
            final daysLeft = difference <= 0 ? '오늘까지' : '$difference일 남았어요';
            personalizedMessages.add({
              "text": "중요한 할 일 '${title}'의 마감이 $daysLeft. 다른 일보다 우선적으로 처리하는 것이 좋겠습니다.",
              "type": "alert"
            });
          }
        }
      }
    }

    // 최종 메시지 구성
    if (personalizedMessages.isNotEmpty) {
      // 맞춤형 메시지가 있으면 해당 메시지 반환 (최대 3개)
      return personalizedMessages.take(3).toList();
    } else {
      // 맞춤형 메시지가 없으면 기본 메시지 반환
      return messages;
    }
  }

  // 추가: 챗봇 대화 API
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      final requestData = {
        "message": message,
        "context": {
          "calendar": _sanitizeCalendarData(calendar),
          "tasks": _sanitizeTaskData(tasks),
        },
        "history": history ?? []
      };

      _printDebugData('/chatbot', requestData);

      final response = await http.post(
        Uri.parse('$baseUrl/chatbot'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('챗봇 응답: $data');
        return data;
      } else {
        print("서버 오류(챗봇): ${response.statusCode} - ${response.body}");
        return {
          "response": "죄송합니다. 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
          "actions": [],
          "timestamp": DateTime.now().toIso8601String()
        };
      }
    } catch (e) {
      print("통신 오류(챗봇): $e");
      return {
        "response": "죄송합니다. 통신 오류가 발생했습니다. 네트워크 연결을 확인해주세요.",
        "actions": [],
        "timestamp": DateTime.now().toIso8601String()
      };
    }
  }

  // 일정 추천 API
  Future<Map<String, dynamic>> getScheduleRecommendations({
    required List<Map<String, dynamic>> calendar,
    required List<Map<String, dynamic>> tasks,
    String? date,
  }) async {
    try {
      // 일정 추천 요청 메시지 생성
      final message = "오늘 시간이 비어있는데 추천 일정을 알려주세요.";

      // 챗봇 API를 통해 추천 요청
      final response = await chatWithAssistant(
          message: message,
          calendar: calendar,
          tasks: tasks,
          history: []
      );

      // 응답에서 추천 액션 확인
      final actions = response['actions'] as List<dynamic>? ?? [];
      final recommendActions = actions.where((action) =>
      action is Map<String, dynamic> &&
          action['action'] == 'recommend_event'
      ).toList();

      // 추천 일정이 있을 경우
      if (recommendActions.isNotEmpty) {
        return response;
      } else {
        // 추천 액션이 없으면 기본 메시지 반환
        return {
          "response": "현재 일정을 분석해 보니, 빈 시간대에 할만한 활동으로는 독서, 운동, 또는 취미 활동을 추천드립니다. 구체적인 일정을 추천해 드릴까요?",
          "actions": [
            {
              "action": "recommend_event",
              "data": {
                "title": "독서 시간",
                "date": date ?? DateTime.now().toString().split(' ')[0],
                "time": "16:00",
                "endTime": "17:00",
                "memo": "자기계발을 위한 독서 시간",
                "importance": 2,
                "urgency": 1
              }
            }
          ],
          "timestamp": DateTime.now().toIso8601String()
        };
      }
    } catch (e) {
      print("통신 오류(일정 추천): $e");
      return {
        "response": "죄송합니다. 일정 추천 중 오류가 발생했습니다.",
        "actions": [],
        "timestamp": DateTime.now().toIso8601String()
      };
    }
  }
}