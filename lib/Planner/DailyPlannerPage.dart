import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';
import '../AI/ai_scheduling_service.dart';
import '../main.dart';
import 'empty_state_widget.dart';
import 'package:momentum_planner/bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:momentum_planner/Todolist/screens/notification_service.dart';
import 'package:momentum_planner/AI/ai_advice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../AI/ai_scheduling_service.dart' as AI;
import 'dart:async';


final String apiUrl = 'https://railwavve-production-68d4.up.railway.app';

class UserInsights {
  final List<int> productiveHours;
  final TaskCompletionPatterns taskCompletionPatterns;
  final double goalAchievementProbability;
  final List<String> breakRecommendations;
  final bool aiPowered;

  UserInsights({
    required this.productiveHours,
    required this.taskCompletionPatterns,
    required this.goalAchievementProbability,
    required this.breakRecommendations,
    required this.aiPowered,
  });
}

class TaskCompletionPatterns {
  final double morningCompletionRate;
  final double afternoonCompletionRate;
  final double eveningCompletionRate;

  TaskCompletionPatterns({
    required this.morningCompletionRate,
    required this.afternoonCompletionRate,
    required this.eveningCompletionRate,
  });
}

class TaskRecommendation {
  final String taskId;
  final String taskTitle;
  String recommendedTime;
  final double confidence;
  final String reason;

  // AI 분석 결과를 위한 추가 필드들
  Map<String, dynamic>? metadata;
  Map<String, dynamic>? aiAnalysis;
  DateTime? createdAt;
  String? source;
  List<String>? tags;

  TaskRecommendation({
    required this.taskId,
    required this.taskTitle,
    required this.recommendedTime,
    required this.confidence,
    required this.reason,
    this.metadata,
    this.aiAnalysis,
    this.createdAt,
    this.source,
    this.tags,
  }) {
    createdAt ??= DateTime.now();
    source ??= 'unknown';
    tags ??= [];
  }


  double get analysisQuality {
    if (aiAnalysis == null) return confidence;

    final semanticScore = aiAnalysis!['semanticSimilarity'] ?? 0.0;
    final temporalScore = aiAnalysis!['temporalFit'] ?? 0.0;
    final patternScore = aiAnalysis!['userPatternMatch'] ?? 0.0;
    final stressScore = aiAnalysis!['stressOptimization'] ?? 0.0;
    final energyScore = aiAnalysis!['energyAlignment'] ?? 0.0;

    return (semanticScore * 0.3 + temporalScore * 0.2 + patternScore * 0.2 +
        stressScore * 0.15 + energyScore * 0.15).clamp(0.0, 1.0);
  }

  String get recommendationType {
    if (aiAnalysis == null) return 'basic';

    final patternMatch = aiAnalysis!['userPatternMatch'] ?? 0.0;
    final semanticSimilarity = aiAnalysis!['semanticSimilarity'] ?? 0.0;

    if (patternMatch > 0.8) return 'pattern_based';
    if (semanticSimilarity > 0.7) return 'semantic_based';
    if (confidence > 0.8) return 'high_confidence';

    return 'general';
  }

  double get priorityScore {
    double score = confidence * 0.4;

    if (aiAnalysis != null) {
      score += analysisQuality * 0.6;
    }

    final now = DateTime.now();
    final recommendedHour = int.tryParse(recommendedTime.split(':')[0]) ?? 9;
    final currentHour = now.hour;

    if ((currentHour - recommendedHour).abs() <= 2) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'recommendedTime': recommendedTime,
      'confidence': confidence,
      'reason': reason,
      'metadata': metadata,
      'aiAnalysis': aiAnalysis,
      'createdAt': createdAt?.toIso8601String(),
      'source': source,
      'tags': tags,
      'analysisQuality': analysisQuality,
      'recommendationType': recommendationType,
      'priorityScore': priorityScore,
    };
  }

  factory TaskRecommendation.fromJson(Map<String, dynamic> json) {
    return TaskRecommendation(
      taskId: _safeExtractString(json, 'taskId') ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
      taskTitle: _safeExtractString(json, 'taskTitle') ?? 'AI 맞춤 추천',
      recommendedTime: _safeExtractString(json, 'recommendedTime') ?? '09:00',
      confidence: _safeExtractDouble(json, 'confidence') ?? 0.7,
      reason: _safeExtractString(json, 'reason') ?? 'AI 분석 기반 추천',
      metadata: _safeExtractMap(json, 'metadata'),
      aiAnalysis: _safeExtractMap(json, 'aiAnalysis'),
      createdAt: _safeExtractDateTime(json, 'createdAt'),
      source: _safeExtractString(json, 'source') ?? 'ai_model',
      tags: _safeExtractStringList(json, 'tags'),
    );
  }

  TaskRecommendation copyWith({
    String? taskId,
    String? taskTitle,
    String? recommendedTime,
    double? confidence,
    String? reason,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? aiAnalysis,
    DateTime? createdAt,
    String? source,
    List<String>? tags,
  }) {
    return TaskRecommendation(
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      recommendedTime: recommendedTime ?? this.recommendedTime,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      metadata: metadata ?? this.metadata,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      tags: tags ?? this.tags,
    );
  }

  static String? _safeExtractString(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;

      if (value is String) {
        return value;
      }

      if (value is Map<String, dynamic>) {
        // Map인 경우 첫 번째 문자열 값을 찾거나 null 반환
        for (var mapValue in value.values) {
          if (mapValue is String && mapValue.isNotEmpty) {
            return mapValue;
          }
        }
        return null;
      }

      if (value is List) {
        // List인 경우 첫 번째 문자열 값을 찾거나 null 반환
        for (var listValue in value) {
          if (listValue is String && listValue.isNotEmpty) {
            return listValue;
          }
        }
        return null;
      }

      return value.toString();
    } catch (e) {
      print('❌ String 추출 오류 ($key): $e, 값: ${json[key]}, 타입: ${json[key].runtimeType}');
      return null;
    }
  }

  static double? _safeExtractDouble(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;

      if (value is double) return value;
      if (value is int) return value.toDouble();

      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }

      if (value is Map<String, dynamic>) {
        // Map인 경우 숫자 값을 찾아서 반환
        for (var mapValue in value.values) {
          if (mapValue is num) {
            return mapValue.toDouble();
          }
        }
        return null;
      }

      if (value is bool) return value ? 1.0 : 0.0;

      return null;
    } catch (e) {
      print('❌ Double 추출 오류 ($key): $e, 값: ${json[key]}, 타입: ${json[key].runtimeType}');
      return null;
    }
  }

  static Map<String, dynamic>? _safeExtractMap(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;

      if (value is Map<String, dynamic>) return value;

      if (value is Map) {
        // Map<String, Object?>를 Map<String, dynamic>으로 변환
        return Map<String, dynamic>.from(value);
      }

      return null;
    } catch (e) {
      print('❌ Map 추출 오류 ($key): $e, 값: ${json[key]}, 타입: ${json[key].runtimeType}');
      return null;
    }
  }

  static DateTime? _safeExtractDateTime(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;

      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    } catch (e) {
      print('❌ DateTime 추출 오류 ($key): $e, 값: ${json[key]}, 타입: ${json[key].runtimeType}');
      return null;
    }
  }

  static List<String>? _safeExtractStringList(Map<String, dynamic> json, String key) {
    try {
      final value = json[key];
      if (value == null) return null;

      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }

      return null;
    } catch (e) {
      print('❌ StringList 추출 오류 ($key): $e, 값: ${json[key]}, 타입: ${json[key].runtimeType}');
      return null;
    }
  }

  @override
  String toString() {
    return 'TaskRecommendation(taskId: $taskId, taskTitle: $taskTitle, '
        'recommendedTime: $recommendedTime, confidence: $confidence, '
        'source: $source, analysisQuality: ${analysisQuality.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskRecommendation &&
        other.taskId == taskId &&
        other.taskTitle == taskTitle &&
        other.recommendedTime == recommendedTime;
  }

  @override
  int get hashCode {
    return taskId.hashCode ^ taskTitle.hashCode ^ recommendedTime.hashCode;
  }
}


class UserInsightsCard extends StatelessWidget {
  final UserInsights insights;

  const UserInsightsCard({Key? key, required this.insights}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: insights.aiPowered
              ? [Colors.purple.shade50, Colors.pink.shade50]
              : [Colors.blue.shade50, Colors.cyan.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: insights.aiPowered ? Colors.purple.shade200 : Colors.blue.shade200
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: insights.aiPowered ? Colors.purple.shade100 : Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  insights.aiPowered ? Icons.psychology : Icons.insights,
                  color: insights.aiPowered ? Colors.purple.shade600 : Colors.blue.shade600,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          insights.aiPowered ? '🤖 실시간 AI 인사이트' : '📊 학습형 인사이트',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (insights.aiPowered) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '목표 달성 확률: ${(insights.goalAchievementProbability * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 나머지 UI 동일...
          SizedBox(height: 12),
          if (insights.productiveHours.isNotEmpty) ...[
            Text(
              '⏰ 생산적인 시간대',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: insights.productiveHours.map((hour) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
          ],

          if (insights.breakRecommendations.isNotEmpty) ...[
            Text(
              '☕ 추천 휴식',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              insights.breakRecommendations.first,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// TaskDataService 클래스 - 누락된 함수들 추가
class TaskDataService {
  static final TaskDataService _instance = TaskDataService._internal();

  factory TaskDataService() {
    return _instance;
  }

  TaskDataService._internal();

  // Firestore 컬렉션 참조
  final CollectionReference todoCollection = FirebaseFirestore.instance
      .collection('todos');
  final CollectionReference plannerCollection = FirebaseFirestore.instance
      .collection('planners');

  // 사용자 ID 저장 변수
  String? currentUserId;

  // Todo List와 Planner 데이터를 분리하여 저장
  final Map<String, List<Todo_Task>> todoTasksByDate = {};
  final Map<String, List<Todo_Task>> plannerTasksByDate = {};

  // 사용자 ID 설정 메서드
  void setUserId(String userId) {
    currentUserId = userId;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String dateToKey(DateTime date) {
    date = _normalizeDate(date);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
        .toString().padLeft(2, '0')}';
  }

  // 날짜 비교 메서드
  bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // 날짜 비교 헬퍼 함수
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Todo List 조회 메서드
  List<Todo_Task> getTodoTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return todoTasksByDate[dateKey]?.where((task) =>
        isSameDate(task.date, date)).toList() ?? [];
  }

  // Planner용 메서드
  List<Todo_Task> getPlannerTasksForDate(DateTime date) {
    final dateKey = dateToKey(date);
    return plannerTasksByDate[dateKey] ?? [];
  }

  void addPlannerTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.add(task);
    } else {
      plannerTasksByDate[dateKey] = [task];
    }

    // Firestore에 저장
    savePlannerTaskToFirestore(task);
  }

  // TaskDataService의 addTodoTask 메서드 수정
  void addTodoTask(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }

    // 기본 태스크 추가
    if (!todoTasksByDate[dateKey]!.any((existingTask) =>
    _isSameDay(existingTask.date, task.date) &&
        existingTask.title == task.title)) {
      todoTasksByDate[dateKey]!.add(task);
      // Firestore에 저장
      saveTodoTaskToFirestore(task);

      // 반복 설정이 있으면 반복 투두들도 생성
      if (task.isRepeating && task.repeatOption != null) {
        _generateAndAddRepeatTodos(task);
      }
    }
  }

  void _addTodoTaskToDateMap(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey] = [];
    }

    // 중복 체크: 동일한 제목과 날짜의 태스크가 있는지 확인
    bool isDuplicate = todoTasksByDate[dateKey]!.any((t) =>
    t.title == task.title &&
        _isSameDay(t.date, task.date));

    if (!isDuplicate) {
      todoTasksByDate[dateKey]!.add(task);
    }
  }

  void _addPlannerTaskToDateMap(Todo_Task task) {
    final dateKey = dateToKey(task.date);
    if (!plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey] = [];
    }

    // 중복 체크
    bool isDuplicate = plannerTasksByDate[dateKey]!.any((t) =>
    t.title == task.title &&
        _isSameDay(t.date, task.date));

    if (!isDuplicate) {
      plannerTasksByDate[dateKey]!.add(task);
    }
  }

  // 개선된 반복 투두 생성 및 추가 함수
  void _generateAndAddRepeatTodos(Todo_Task baseTask) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 365)); // 1년간 반복 생성
    DateTime currentDate = baseTask.date;

    // 최대 100개까지만 생성 (무한 반복 방지)
    int generatedCount = 0;
    const int maxRepeatTasks = 100;

    while (currentDate.isBefore(endDate) && generatedCount < maxRepeatTasks) {
      DateTime nextDate = _getNextRepeatDateForTask(currentDate, baseTask);

      if (nextDate.isAfter(endDate)) break;

      // 원본 날짜가 아닌 경우에만 반복 태스크 생성
      if (!_isSameDay(nextDate, baseTask.date)) {
        final repeatTask = baseTask.copyWith(
          id: '${baseTask.id}_repeat_${nextDate.millisecondsSinceEpoch}',
          date: nextDate,
          isCompleted: false, // 반복 일정은 항상 미완료로 시작
          notificationId: null, // 새로운 알림 ID 필요
        );

        // 로컬 메모리에 추가
        final dateKey = dateToKey(nextDate);
        if (!todoTasksByDate.containsKey(dateKey)) {
          todoTasksByDate[dateKey] = [];
        }

        // 중복 체크 후 추가
        bool isDuplicate = todoTasksByDate[dateKey]!.any((t) =>
        t.title == repeatTask.title &&
            _isSameDay(t.date, repeatTask.date));

        if (!isDuplicate) {
          todoTasksByDate[dateKey]!.add(repeatTask);
          // Firestore에도 저장
          saveTodoTaskToFirestore(repeatTask);
          generatedCount++;
        }
      }

      currentDate = nextDate;
    }
  }

  // 태스크 기반 다음 반복 날짜 계산 함수
  DateTime _getNextRepeatDateForTask(DateTime currentDate, Todo_Task task) {
    switch (task.repeatOption) {
      case '매일':
        return currentDate.add(Duration(days: 1));

      case '매주':
        return currentDate.add(Duration(days: 7));

      case '매달':
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int targetDay = currentDate.day;
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay);

      case '매년':
        return DateTime(
            currentDate.year + 1, currentDate.month, currentDate.day);

      case '매요일':
        if (task.repeatDays == null || task.repeatDays!.isEmpty) {
          return currentDate.add(Duration(days: 1));
        }

        // 다음 해당 요일 찾기
        DateTime nextDate = currentDate.add(Duration(days: 1));
        int searchLimit = 0;
        while (!task.repeatDays!.contains(nextDate.weekday - 1) &&
            searchLimit < 7) {
          nextDate = nextDate.add(Duration(days: 1));
          searchLimit++;
        }
        return nextDate;

      case '기타':
        final customDays = task.repeatCustomDays ?? 1;
        return currentDate.add(Duration(days: customDays));

      default:
        return currentDate.add(Duration(days: 1));
    }
  }

  List<int>? _parseRepeatDays(dynamic repeatDaysData) {
    if (repeatDaysData == null) return null;

    try {
      if (repeatDaysData is List) {
        // List인 경우 각 요소를 안전하게 int로 변환
        return repeatDaysData.map((e) {
          if (e is int) return e;
          if (e is String) {
            final parsed = int.tryParse(e);
            if (parsed != null) return parsed;
          }
          return 0; // 기본값
        }).where((e) => e >= 0 && e <= 6).toList(); // 유효한 요일만 필터링
      } else if (repeatDaysData is String) {
        // String인 경우 파싱
        String cleanString = repeatDaysData.replaceAll('[', '').replaceAll(
            ']', '').replaceAll(' ', '');
        if (cleanString.isEmpty) return null;

        return cleanString
            .split(',')
            .map((s) {
          final parsed = int.tryParse(s.trim());
          return parsed ?? 0;
        })
            .where((e) => e >= 0 && e <= 6) // 유효한 요일만 필터링
            .toList();
      }
    } catch (e) {
      print('repeatDays 파싱 오류: $e, 데이터: $repeatDaysData');
    }

    return null;
  }

  Todo_Task _createTodoTaskFromData(Map<String, dynamic> data, String docId,
      DateTime dateTime) {
    // repeatDays 안전하게 파싱
    List<int>? safeRepeatDays;
    try {
      safeRepeatDays = _parseRepeatDays(data['repeatDays']);
    } catch (e) {
      print('repeatDays 파싱 실패: $e');
      safeRepeatDays = null;
    }

    return Todo_Task(
      id: docId,
      userId: data['userId'] ?? currentUserId ?? '',
      title: data['title'] ?? '',
      description: data['description']?.toString(),
      time: data['time']?.toString(),
      endTime: data['endTime']?.toString(),
      date: dateTime,
      isImportant: data['isImportant'] ?? false,
      isUrgent: data['isUrgent'] ?? false,
      memo: data['memo']?.toString(),
      location: data['location']?.toString(),
      importance: data['importance'] ?? 1,
      urgency: data['urgency'] ?? 1,
      isCompleted: data['isCompleted'] ?? false,
      dueDate: data['dueDate']?.toString() != null
          ? DateTime.tryParse(data['dueDate']) ?? null
          : null,
      isRepeating: data['isRepeating'] ?? false,
      repeatOption: data['repeatOption']?.toString(),
      repeatDays: safeRepeatDays,
      // 안전하게 파싱된 데이터 사용
      repeatCustomDays: data['repeatCustomDays'],
    );
  }

  // Todo Task를 Firestore에 저장 (반복 필드 추가)
  Future<void> saveTodoTaskToFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      await todoCollection.add({
        'userId': currentUserId,
        'title': task.title,
        'description': task.description,
        'time': task.time,
        'endTime': task.endTime,
        'date': task.date.toIso8601String(),
        'isImportant': task.isImportant,
        'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating, // 반복 필드 추가
        'repeatOption': task.repeatOption,
        'repeatDays': task.repeatDays,
        'repeatCustomDays': task.repeatCustomDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Todo Task 저장 오류: $e');
    }
  }

  // Planner Task를 Firestore에 저장 (반복 필드 추가)
  Future<void> savePlannerTaskToFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      await plannerCollection.add({
        'userId': currentUserId,
        'title': task.title,
        'description': task.description,
        'time': task.time,
        'endTime': task.endTime,
        'date': task.date.toIso8601String(),
        'isImportant': task.isImportant,
        'isUrgent': task.isUrgent,
        'memo': task.memo,
        'location': task.location,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating, // 반복 필드 추가
        'repeatOption': task.repeatOption,
        'repeatDays': task.repeatDays,
        'repeatCustomDays': task.repeatCustomDays,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Planner Task 저장 오류: $e');
    }
  }

  // Task 상태 업데이트 (완료/미완료)
  Future<void> updateTaskCompletionInFirestore(Todo_Task task,
      bool isCompleted) async {
    if (currentUserId == null) return;

    try {
      // Todo 컬렉션 확인
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.update({'isCompleted': isCompleted});
      }

      // Planner 컬렉션 확인
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in plannerQuery.docs) {
        await doc.reference.update({'isCompleted': isCompleted});
      }
    } catch (e) {
      print('Task 상태 업데이트 오류: $e');
    }
  }

  // Task 상태 업데이트 함수 개선
  void updateTaskStatus(Todo_Task task, bool isCompleted) {
    final dateKey = dateToKey(task.date);

    // 로컬 데이터 업데이트
    if (todoTasksByDate.containsKey(dateKey)) {
      try {
        final todoTask = todoTasksByDate[dateKey]!
            .firstWhere((t) =>
        t.title == task.title && _isSameDay(t.date, task.date));
        todoTask.isCompleted = isCompleted;
      } catch (e) {}
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      try {
        final plannerTask = plannerTasksByDate[dateKey]!
            .firstWhere((t) =>
        t.title == task.title && _isSameDay(t.date, task.date));
        plannerTask.isCompleted = isCompleted;
      } catch (e) {}
    }

    // 태스크 자체 업데이트
    task.isCompleted = isCompleted;

    // Firestore 업데이트
    updateTaskCompletionInFirestore(task, isCompleted);
  }

  // updateTaskInFirestore 함수 추가
  Future<void> updateTaskInFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      // Todo 컬렉션에서 업데이트
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.update({
          'title': task.title,
          'description': task.description,
          'time': task.time,
          'endTime': task.endTime,
          'date': task.date.toIso8601String(),
          'isImportant': task.isImportant,
          'isUrgent': task.isUrgent,
          'memo': task.memo,
          'location': task.location,
          'importance': task.importance,
          'urgency': task.urgency,
          'isCompleted': task.isCompleted,
          'dueDate': task.dueDate?.toIso8601String(),
          'isRepeating': task.isRepeating,
          'repeatOption': task.repeatOption,
          'repeatDays': task.repeatDays,
          'repeatCustomDays': task.repeatCustomDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Planner 컬렉션에서도 업데이트
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in plannerQuery.docs) {
        await doc.reference.update({
          'title': task.title,
          'description': task.description,
          'time': task.time,
          'endTime': task.endTime,
          'date': task.date.toIso8601String(),
          'isImportant': task.isImportant,
          'isUrgent': task.isUrgent,
          'memo': task.memo,
          'location': task.location,
          'importance': task.importance,
          'urgency': task.urgency,
          'isCompleted': task.isCompleted,
          'dueDate': task.dueDate?.toIso8601String(),
          'isRepeating': task.isRepeating,
          'repeatOption': task.repeatOption,
          'repeatDays': task.repeatDays,
          'repeatCustomDays': task.repeatCustomDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('Task 업데이트 완료: ${task.title}');
    } catch (e) {
      print('Task 업데이트 오류: $e');
    }
  }

  // Firestore에서 반복 일정도 제대로 로드하도록 수정
  Future<void> loadTasksFromFirestore(String userId) async {
    setUserId(userId);

    // 데이터를 로드하기 전에 기존 데이터 초기화
    todoTasksByDate.clear();
    plannerTasksByDate.clear();

    // Todo 데이터 로드
    try {
      final todoSnapshot = await todoCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in todoSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTime = DateTime.parse(data['date']);

        // 모든 투두 태스크 생성 (반복 여부 상관없이)
        final task = _createTodoTaskFromData(data, doc.id, dateTime);
        _addTodoTaskToDateMap(task);
      }

      // Planner 데이터 로드
      final plannerSnapshot = await plannerCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in plannerSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateTime = DateTime.parse(data['date']);

        final task = _createTodoTaskFromData(data, doc.id, dateTime);
        _addPlannerTaskToDateMap(task);
      }

      print('Firestore 데이터 로드 완료: Todo ${todoTasksByDate
          .length}, Planner ${plannerTasksByDate.length}');
    } catch (e) {
      print('Firestore 데이터 로드 오류: $e');
    }
  }

  // 특정 날짜의 Planner 작업 모두 삭제 (개선된 버전)
  Future<void> clearPlannerTasksForDate(DateTime date) async {
    if (currentUserId == null) return;

    final dateKey = dateToKey(date);
    final dateStr = date.toIso8601String().split('T')[0]; // 날짜만 추출

    try {
      // 1. 로컬 캐시 데이터 삭제
      plannerTasksByDate.remove(dateKey);
      todoTasksByDate.remove(dateKey);

      // 2. Planner 컬렉션에서 삭제
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasDocumentsToDelete = false;

      for (var doc in plannerQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['date'] != null) {
          final docDate = DateTime.parse(data['date']).toIso8601String().split(
              'T')[0];
          if (docDate == dateStr) {
            batch.delete(doc.reference);
            hasDocumentsToDelete = true;
          }
        }
      }

      // 3. Todo 컬렉션에서도 해당 날짜 삭제
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .get();

      for (var doc in todoQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['date'] != null) {
          final docDate = DateTime.parse(data['date']).toIso8601String().split(
              'T')[0];
          if (docDate == dateStr) {
            batch.delete(doc.reference);
            hasDocumentsToDelete = true;
          }
        }
      }

      // 4. Events 컬렉션에서도 해당 날짜 삭제
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: currentUserId)
          .get();

      for (var doc in eventsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['startDate'] != null) {
          final eventDate = (data['startDate'] as Timestamp).toDate();
          final eventDateStr = eventDate.toIso8601String().split('T')[0];
          if (eventDateStr == dateStr) {
            batch.delete(doc.reference);
            hasDocumentsToDelete = true;
          }
        }
      }

      // 5. 배치 커밋
      if (hasDocumentsToDelete) {
        await batch.commit();
      }

      print('모든 컬렉션에서 $dateKey 날짜 데이터 삭제 완료');
    } catch (e) {
      print('전체 데이터 삭제 오류: $e');
    }
  }

  // Firestore에서 Task 삭제하는 함수
  Future<void> removeTaskFromFirestore(Todo_Task task) async {
    if (currentUserId == null) return;

    try {
      // 1. Todo 컬렉션에서 삭제 (제목과 날짜 기준)
      final todoQuery = await todoCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.delete();
        print('Todo 컬렉션에서 삭제: ${task.title}');
      }

      // 2. Planner 컬렉션에서 삭제 (제목과 날짜 기준)
      final plannerQuery = await plannerCollection
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .where('date', isEqualTo: task.date.toIso8601String())
          .get();

      for (var doc in plannerQuery.docs) {
        await doc.reference.delete();
        print('Planner 컬렉션에서 삭제: ${task.title}');
      }

      // 3. Events 컬렉션에서도 삭제 (캘린더 일정인 경우)
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: currentUserId)
          .where('title', isEqualTo: task.title)
          .get();

      for (var doc in eventsQuery.docs) {
        final data = doc.data();
        final eventStartDate = (data['startDate'] as Timestamp).toDate();

        // 같은 날짜의 이벤트만 삭제
        if (eventStartDate.year == task.date.year &&
            eventStartDate.month == task.date.month &&
            eventStartDate.day == task.date.day) {
          await doc.reference.delete();
          print('Events 컬렉션에서 삭제: ${task.title}');
        }
      }

      print('모든 컬렉션에서 ${task.title} 삭제 완료');
    } catch (e) {
      print('Task 삭제 오류: $e');
    }
  }

  // 기존 removeTask 함수 수정
  Future<void> removeTask(Todo_Task task) async {
    // 로컬 데이터 삭제
    final dateKey = dateToKey(task.date);
    if (todoTasksByDate.containsKey(dateKey)) {
      todoTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }
    if (plannerTasksByDate.containsKey(dateKey)) {
      plannerTasksByDate[dateKey]!.removeWhere((t) => t.title == task.title);
    }

    // Firestore에서도 삭제
    await removeTaskFromFirestore(task);
  }

  // 진행률 계산 - 전체 진행률
  double calculateCombinedProgressForDate(DateTime date) {
    final todoTasks = getTodoTasksForDate(date);
    final plannerTasks = getPlannerTasksForDate(date);
    final totalTasks = todoTasks.length + plannerTasks.length;
    if (totalTasks == 0) return 0.0;
    final completedTasks = todoTasks
        .where((task) => task.isCompleted)
        .length +
        plannerTasks
            .where((task) => task.isCompleted)
            .length;
    return (completedTasks / totalTasks) * 100;
  }

  // 투두리스트 진행률 계산
  double calculateTodoProgressForDate(DateTime date) {
    final todoTasks = getTodoTasksForDate(date);
    if (todoTasks.isEmpty) return 0.0;
    final completedTasks = todoTasks
        .where((task) => task.isCompleted)
        .length;
    return (completedTasks / todoTasks.length) * 100;
  }

  // 플래너 진행률 계산
  double calculatePlannerProgressForDate(DateTime date) {
    final plannerTasks = getPlannerTasksForDate(date);
    if (plannerTasks.isEmpty) return 0.0;
    final completedTasks = plannerTasks
        .where((task) => task.isCompleted)
        .length;
    return (completedTasks / plannerTasks.length) * 100;
  }
}

class DailyPlannerPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>>? calendarData; // calendarData를 선택적으로 추가

  const DailyPlannerPage({
    Key? key,
    required this.userId,
    this.calendarData, // 선택적 매개변수로 정의
  }) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}



class _DailyPlannerPageState extends State<DailyPlannerPage> {
  late String userId; // 나중에 초기화할 변수
  double progressPercentage = 0.0; // 전체 진행률 (기존 유지)
  double todoProgressPercentage = 0.0; // 투두 진행률 (새로 추가)
  double plannerProgressPercentage = 0.0; // 플래너 진행률 (새로 추가)
  Timer? _insightsUpdateTimer;
  final NotificationService _notificationService = NotificationService();
  final AISchedulingService _aiService = AISchedulingService();
  List<TaskRecommendation> _aiRecommendations = [];
  UserInsights? _userInsights;
  bool _isLoadingAI = false;
  bool _showAIRecommendations = false;
  String _aiRecommendationStatus = 'idle';
  static const String BASE_SERVER_URL = 'https://railwavve-production-68d4.up.railway.app';


  bool isPlannerView = true; // true for planner, false for todo list
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> calendarEvents = [];
  bool isLoading = false;
  TodoListScreenState? todoListScreenState;
  final TaskDataService _taskDataService = TaskDataService();


  @override
  void initState() {
    super.initState();
    userId = widget.userId ?? '';

    // 기존 초기화 코드...

    // 주기적 인사이트 업데이트 설정 (5분마다)
    Timer.periodic(Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadUserInsights();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    //print('📌 didChangeDependencies 시작');
    //print('📌 현재 userId: "$userId"');

    // Arguments에서 userId 가져오기 시도
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    print('📌 Arguments: $args');

    String finalUserId = '';

    // 우선순위: arguments > widget.userId
    if (args != null && args['userId'] != null && args['userId'].toString().isNotEmpty) {
      finalUserId = args['userId'].toString();
      print('📌 Arguments에서 userId 사용: "$finalUserId"');
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      finalUserId = widget.userId!;
      print('📌 widget.userId 사용: "$finalUserId"');
    } else {
      print('❌ userId를 찾을 수 없음');
      return;
    }

    // userId 업데이트가 필요한 경우
    if (finalUserId != userId) {
      print('📌 userId 업데이트: "$userId" -> "$finalUserId"');
      setState(() {
        userId = finalUserId;
      });

      // 서비스 초기화
      _taskDataService.setUserId(userId);
      _loadData();
      _loadUserInsights();

      // 캘린더 카운트 업데이트
      Future.delayed(Duration(milliseconds: 1000), () {
        _fetchCalendarAndTodoCount();
      });
    } else if (userId.isNotEmpty && _calendarCount == 0 && _todoCount == 0) {
      // userId는 같지만 아직 데이터가 로드되지 않은 경우
      print('📌 데이터 재로드 시도');
      _taskDataService.setUserId(userId);
      _loadData();
      _loadUserInsights();

      Future.delayed(Duration(milliseconds: 1000), () {
        _fetchCalendarAndTodoCount();
      });
    }

    print('📌 최종 userId: "$userId"');
  }




// 파이어스토어에서 데이터 로드하는 메서드 수정
  Future<void> _loadData() async {
    await _taskDataService.loadTasksFromFirestore(userId);
    updateProgress();
  }


  // 3. updateProgress 메서드 수정 (플래너 진행률만 계산)
  void updateProgress() {
    setState(() {
      // 플래너 진행률만 계산
      plannerProgressPercentage = _taskDataService.calculatePlannerProgressForDate(selectedDate);

      // 투두 진행률도 여전히 계산 (투두 뷰에서 사용)
      todoProgressPercentage = _taskDataService.calculateTodoProgressForDate(selectedDate);

      // 전체 진행률은 플래너 진행률로 설정
      progressPercentage = plannerProgressPercentage;
    });
  }


  final TextEditingController _inputController = TextEditingController();
  String _algorithmOutput = '';
  String _geminiOutput = '';
  bool _isLoading = false;
  String _errorMessage = '';

  // Flask 서버 URL (실제 서버 주소로 변경 필요)
  final String serverUrl_1 = 'https://railwavve-production-68d4.up.railway.app/schedule_';  // 에뮬레이터 사용 시
  final String serverUrl__ = 'https://railwavve-production-68d4.up.railway.app/schedule_';  // 웹에서 테스트 시
  // final String serverUrl = 'http://your-server-ip:5000/schedule_';  // 실제 서버 IP로 접속 시

  // 1. 메인 사용자 인사이트 로드 함수 - 실제 데이터 기반으로 계산
  Future<void> _loadUserInsights() async {
    if (userId.isEmpty) {
      print('userId가 비어있어서 인사이트를 로드할 수 없습니다.');
      return;
    }

    try {
      print('📊 실제 데이터 기반 사용자 인사이트 계산 시작: $userId');

      // 실제 사용자 데이터 분석 (항상 실행)
      final realInsights = await _calculateRealUserInsights();

      if (mounted) {
        setState(() {
          _userInsights = realInsights;
        });
        print('✅ 실제 데이터 기반 사용자 인사이트 설정 완료');
      }

    } catch (e) {
      print('❌ 인사이트 계산 실패: $e');

      // 폴백도 동적 데이터로 변경
      if (mounted) {
        setState(() async {
          _userInsights = await _generateDynamicFallbackInsights();
        });
        print('🔄 동적 폴백 인사이트로 설정 완료');
      }
    }
  }
  Future<UserInsights> _generateDynamicFallbackInsights() async {
    try {
      // 현재 가지고 있는 데이터라도 분석해서 사용
      final now = DateTime.now();
      final recentTasks = <Todo_Task>[];

      // 최근 7일간이라도 데이터 수집
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dayTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        recentTasks.addAll([...dayTasks, ...plannerTasks]);
      }

      // 실제 데이터가 있으면 분석, 없으면 기본값
      if (recentTasks.isNotEmpty) {
        print('📈 최근 7일 데이터로 폴백 인사이트 생성: ${recentTasks.length}개 태스크');

        // 시간대별 분석
        final hourlySuccess = <int, double>{};
        for (var task in recentTasks) {
          if (task.time != null) {
            try {
              final hour = _parseTimeToHour(task.time!);
              if (!hourlySuccess.containsKey(hour)) {
                hourlySuccess[hour] = 0.0;
              }
              hourlySuccess[hour] = hourlySuccess[hour]! + (task.isCompleted ? 1.0 : 0.0);
            } catch (e) {}
          }
        }

        // 생산적인 시간대 계산
        final productiveHours = hourlySuccess.entries
            .where((e) => e.value >= 1.0) // 1번 이상 성공한 시간대
            .map((e) => e.key)
            .toList()..sort();

        // 완료율 계산
        final completedTasks = recentTasks.where((t) => t.isCompleted).length;
        final totalTasks = recentTasks.length;
        final completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.5;

        // 시간대별 완료 패턴
        final morningTasks = recentTasks.where((t) => t.time != null && _getTimeCategory(t.time!) == 'morning').toList();
        final afternoonTasks = recentTasks.where((t) => t.time != null && _getTimeCategory(t.time!) == 'afternoon').toList();
        final eveningTasks = recentTasks.where((t) => t.time != null && _getTimeCategory(t.time!) == 'evening').toList();

        final morningRate = morningTasks.isNotEmpty
            ? morningTasks.where((t) => t.isCompleted).length / morningTasks.length
            : 0.6;
        final afternoonRate = afternoonTasks.isNotEmpty
            ? afternoonTasks.where((t) => t.isCompleted).length / afternoonTasks.length
            : 0.7;
        final eveningRate = eveningTasks.isNotEmpty
            ? eveningTasks.where((t) => t.isCompleted).length / eveningTasks.length
            : 0.5;

        // 동적 휴식 추천
        final breakRecommendations = _generateDynamicBreakRecommendations(recentTasks);

        return UserInsights(
          productiveHours: productiveHours.isNotEmpty ? productiveHours : [9, 14],
          taskCompletionPatterns: TaskCompletionPatterns(
            morningCompletionRate: morningRate,
            afternoonCompletionRate: afternoonRate,
            eveningCompletionRate: eveningRate,
          ),
          goalAchievementProbability: completionRate,
          breakRecommendations: breakRecommendations,
          aiPowered: true,
        );
      } else {
        print('📊 데이터 없음 - 학습형 기본 인사이트 생성');
        // 데이터가 없어도 사용자가 사용할수록 쌓이도록 기본값 설정
        return UserInsights(
          productiveHours: [9, 10, 14, 15], // 일반적인 생산적 시간
          taskCompletionPatterns: TaskCompletionPatterns(
            morningCompletionRate: 0.7,
            afternoonCompletionRate: 0.8,
            eveningCompletionRate: 0.6,
          ),
          goalAchievementProbability: 0.65,
          breakRecommendations: [
            '오전 10:30에 15분 휴식',
            '오후 3:00에 10분 휴식',
            '저녁 식사 후 가벼운 산책'
          ],
          aiPowered: false, // 실제 데이터가 아님을 표시
        );
      }
    } catch (e) {
      print('동적 폴백 인사이트 생성 오류: $e');
      // 최후의 수단 기본값
      return UserInsights(
        productiveHours: [9, 10, 14, 15],
        taskCompletionPatterns: TaskCompletionPatterns(
          morningCompletionRate: 0.7,
          afternoonCompletionRate: 0.8,
          eveningCompletionRate: 0.6,
        ),
        goalAchievementProbability: 0.65,
        breakRecommendations: ['규칙적인 휴식을 취하세요'],
        aiPowered: false,
      );
    }
  }

// 3. 시간 카테고리 헬퍼 함수
  String _getTimeCategory(String timeString) {
    try {
      final hour = _parseTimeToHour(timeString);
      if (hour >= 6 && hour <= 11) return 'morning';
      if (hour >= 12 && hour <= 17) return 'afternoon';
      if (hour >= 18 && hour <= 22) return 'evening';
      return 'other';
    } catch (e) {
      return 'other';
    }
  }

// 4. 동적 휴식 추천 생성
  List<String> _generateDynamicBreakRecommendations(List<Todo_Task> recentTasks) {
    final recommendations = <String>[];

    // 작업량 분석
    final avgDailyTasks = recentTasks.length / 7.0;

    // 스트레스 레벨 분석
    final highPriorityTasks = recentTasks.where((t) => t.importance >= 4 || t.urgency >= 4).length;
    final stressRatio = recentTasks.isNotEmpty ? highPriorityTasks / recentTasks.length : 0.0;

    // 가장 바쁜 시간대 찾기
    final hourlyTaskCount = <int, int>{};
    for (var task in recentTasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          hourlyTaskCount[hour] = (hourlyTaskCount[hour] ?? 0) + 1;
        } catch (e) {}
      }
    }

    final busiestHour = hourlyTaskCount.entries.isNotEmpty
        ? hourlyTaskCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 14; // 기본값

    // 동적 추천 생성
    if (stressRatio > 0.6) {
      recommendations.add('오전 10:00에 5분 명상으로 스트레스 해소');
      recommendations.add('${busiestHour - 1}시에 10분 휴식으로 집중력 회복');
      recommendations.add('저녁 20:00에 가벼운 산책으로 마음 정리');
    } else if (avgDailyTasks > 8) {
      recommendations.add('오전 10:30에 15분 휴식');
      recommendations.add('오후 ${busiestHour + 1}:00에 10분 휴식');
      recommendations.add('하루 종료 후 30분 여유시간');
    } else {
      recommendations.add('오후 3:00에 가벼운 티타임');
      recommendations.add('저녁 산책으로 하루 마무리');
      recommendations.add('자기계발 시간 확보');
    }

    return recommendations;
  }

// 5. 실시간 업데이트를 위한 함수 (태스크 상태 변경 시 호출)
  void _updateInsightsOnTaskCompletion() {
    // 태스크 완료 시 인사이트 재계산
    Future.delayed(Duration(milliseconds: 500), () {
      _loadUserInsights();
    });
  }

// 6. updateTaskStatus 함수 수정하여 인사이트 실시간 업데이트
  void updateTaskStatus(Todo_Task task, bool isCompleted) {
    final dateKey = _taskDataService.dateToKey(task.date);

    // 기존 로직...
    if (_taskDataService.todoTasksByDate.containsKey(dateKey)) {
      try {
        final todoTask = _taskDataService.todoTasksByDate[dateKey]!
            .firstWhere((t) => t.title == task.title && _taskDataService.isSameDate(t.date, task.date));
        todoTask.isCompleted = isCompleted;
      } catch (e) {}
    }

    task.isCompleted = isCompleted;
    _taskDataService.updateTaskCompletionInFirestore(task, isCompleted);

    // 인사이트 실시간 업데이트 추가
    _updateInsightsOnTaskCompletion();
  }

// 7. 새로운 태스크 추가 시에도 인사이트 업데이트
  void addNewTask(Todo_Task task) {
    _taskDataService.addTodoTask(task);
    // 새 태스크 추가 시에도 인사이트 재계산
    _updateInsightsOnTaskCompletion();
  }

// 2. 실제 사용자 데이터 기반 인사이트 계산
  Future<UserInsights> _calculateRealUserInsights() async {
    try {
      final now = DateTime.now();

      // 최근 30일간의 실제 데이터 분석
      final analysisResult = await _analyzeUserBehaviorLast30Days();

      // 생산적인 시간대 계산 (실제 완료율 기반)
      final productiveHours = _calculateProductiveHours(analysisResult);

      // 시간대별 완료 패턴 계산
      final completionPatterns = _calculateCompletionPatterns(analysisResult);

      // 목표 달성 확률 계산 (최근 성과 기반)
      final goalAchievementProb = _calculateGoalAchievementProbability(analysisResult);

      // 개인화된 휴식 추천
      final breakRecommendations = _generatePersonalizedBreakRecommendations(analysisResult);

      return UserInsights(
        productiveHours: productiveHours,
        taskCompletionPatterns: completionPatterns,
        goalAchievementProbability: goalAchievementProb,
        breakRecommendations: breakRecommendations,
        aiPowered: true,
      );

    } catch (e) {
      print('실제 인사이트 계산 오류: $e');
      throw e;
    }
  }

// 3. 최근 30일간 사용자 행동 분석
  Future<Map<String, dynamic>> _analyzeUserBehaviorLast30Days() async {
    final now = DateTime.now();
    final analysisData = <String, dynamic>{
      'dailyData': <Map<String, dynamic>>[],
      'hourlyCompletionRates': <int, List<double>>{},
      'categorySuccessRates': <String, Map<String, int>>{},
      'totalTasks': 0,
      'completedTasks': 0,
      'averageDailyTasks': 0.0,
      'consistencyScore': 0.0,
      'workloadTrends': <double>[],
    };

    // 최근 30일간 데이터 수집
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final todoTasks = _taskDataService.getTodoTasksForDate(date);
      final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
      final allTasks = [...todoTasks, ...plannerTasks];

      if (allTasks.isNotEmpty) {
        final completed = allTasks.where((task) => task.isCompleted).length;
        final total = allTasks.length;
        final completionRate = completed / total;

        // 일별 데이터 저장
        final dayData = {
          'date': date,
          'totalTasks': total,
          'completedTasks': completed,
          'completionRate': completionRate,
          'weekday': date.weekday,
          'hourlyData': <int, Map<String, int>>{},
          'categoryData': <String, Map<String, int>>{},
        };

        // 시간대별 분석
        final hourlyStats = <int, Map<String, int>>{};
        final categoryStats = <String, Map<String, int>>{};

        for (var task in allTasks) {
          // 시간대 분석
          if (task.time != null && task.time!.isNotEmpty) {
            try {
              final hour = _parseTimeToHour(task.time!);
              if (!hourlyStats.containsKey(hour)) {
                hourlyStats[hour] = {'total': 0, 'completed': 0};
              }
              hourlyStats[hour]!['total'] = hourlyStats[hour]!['total']! + 1;
              if (task.isCompleted) {
                hourlyStats[hour]!['completed'] = hourlyStats[hour]!['completed']! + 1;
              }

              // 전체 시간별 통계에 추가
              if (!analysisData['hourlyCompletionRates'].containsKey(hour)) {
                analysisData['hourlyCompletionRates'][hour] = <double>[];
              }
              (analysisData['hourlyCompletionRates'][hour] as List<double>)
                  .add(task.isCompleted ? 1.0 : 0.0);
            } catch (e) {
              // 시간 파싱 실패 시 무시
            }
          }

          // 카테고리별 분석
          final category = _getTaskType(task.title);
          if (!categoryStats.containsKey(category)) {
            categoryStats[category] = {'total': 0, 'completed': 0};
          }
          categoryStats[category]!['total'] = categoryStats[category]!['total']! + 1;
          if (task.isCompleted) {
            categoryStats[category]!['completed'] = categoryStats[category]!['completed']! + 1;
          }

          // 전체 카테고리 통계에 추가
          if (!analysisData['categorySuccessRates'].containsKey(category)) {
            analysisData['categorySuccessRates'][category] = {'total': 0, 'completed': 0};
          }
          final globalCategoryStats = analysisData['categorySuccessRates'][category] as Map<String, int>;
          globalCategoryStats['total'] = globalCategoryStats['total']! + 1;
          if (task.isCompleted) {
            globalCategoryStats['completed'] = globalCategoryStats['completed']! + 1;
          }
        }

        dayData['hourlyData'] = hourlyStats;
        dayData['categoryData'] = categoryStats;
        (analysisData['dailyData'] as List<Map<String, dynamic>>).add(dayData);

        // 전체 통계 업데이트
        analysisData['totalTasks'] += total;
        analysisData['completedTasks'] += completed;
        (analysisData['workloadTrends'] as List<double>).add(total.toDouble());
      }
    }

    // 평균 일일 태스크 수 계산
    final dailyData = analysisData['dailyData'] as List<Map<String, dynamic>>;
    if (dailyData.isNotEmpty) {
      final totalDays = dailyData.length;
      analysisData['averageDailyTasks'] = analysisData['totalTasks'] / totalDays;

      // 일관성 점수 계산 (완료율의 표준편차 기반)
      final completionRates = dailyData.map((day) => day['completionRate'] as double).toList();
      if (completionRates.isNotEmpty) {
        final mean = completionRates.reduce((a, b) => a + b) / completionRates.length;
        final variance = completionRates.map((rate) => pow(rate - mean, 2)).reduce((a, b) => a + b) / completionRates.length;
        analysisData['consistencyScore'] = 1.0 - sqrt(variance); // 일관성이 높을수록 1에 가까움
      }
    }

    print('📊 30일간 분석 완료: ${analysisData['totalTasks']}개 태스크, ${analysisData['completedTasks']}개 완료');
    return analysisData;
  }

// 4. 생산적인 시간대 계산 (실제 완료율 80% 이상인 시간대)
  List<int> _calculateProductiveHours(Map<String, dynamic> analysisData) {
    final productiveHours = <int>[];
    final hourlyData = analysisData['hourlyCompletionRates'] as Map<int, List<double>>;

    hourlyData.forEach((hour, completionList) {
      if (completionList.length >= 3) { // 최소 3번 이상 활동한 시간대만
        final averageCompletion = completionList.reduce((a, b) => a + b) / completionList.length;
        if (averageCompletion >= 0.8) { // 80% 이상 완료율
          productiveHours.add(hour);
        }
      }
    });

    // 생산적인 시간대가 없으면 기본값 반환
    if (productiveHours.isEmpty) {
      return [9, 10, 14, 15]; // 기본 생산적 시간대
    }

    productiveHours.sort();
    print('🚀 실제 생산적 시간대: $productiveHours');
    return productiveHours;
  }

// 5. 시간대별 완료 패턴 계산
  TaskCompletionPatterns _calculateCompletionPatterns(Map<String, dynamic> analysisData) {
    final hourlyData = analysisData['hourlyCompletionRates'] as Map<int, List<double>>;

    double morningRate = 0.0;
    double afternoonRate = 0.0;
    double eveningRate = 0.0;

    int morningCount = 0;
    int afternoonCount = 0;
    int eveningCount = 0;

    hourlyData.forEach((hour, completionList) {
      if (completionList.isNotEmpty) {
        final averageCompletion = completionList.reduce((a, b) => a + b) / completionList.length;

        if (hour >= 6 && hour <= 11) { // 아침 (6-11시)
          morningRate += averageCompletion;
          morningCount++;
        } else if (hour >= 12 && hour <= 17) { // 오후 (12-17시)
          afternoonRate += averageCompletion;
          afternoonCount++;
        } else if (hour >= 18 && hour <= 23) { // 저녁 (18-23시)
          eveningRate += averageCompletion;
          eveningCount++;
        }
      }
    });

    // 평균 계산
    final finalMorningRate = morningCount > 0 ? morningRate / morningCount : 0.8;
    final finalAfternoonRate = afternoonCount > 0 ? afternoonRate / afternoonCount : 0.7;
    final finalEveningRate = eveningCount > 0 ? eveningRate / eveningCount : 0.6;

    print('⏰ 실제 시간대별 완료율 - 아침: ${(finalMorningRate*100).toInt()}%, 오후: ${(finalAfternoonRate*100).toInt()}%, 저녁: ${(finalEveningRate*100).toInt()}%');

    return TaskCompletionPatterns(
      morningCompletionRate: finalMorningRate,
      afternoonCompletionRate: finalAfternoonRate,
      eveningCompletionRate: finalEveningRate,
    );
  }

// 6. 목표 달성 확률 계산 (최근 7일 평균 완료율 기반)
  double _calculateGoalAchievementProbability(Map<String, dynamic> analysisData) {
    final dailyData = analysisData['dailyData'] as List<Map<String, dynamic>>;

    if (dailyData.isEmpty) return 0.75; // 기본값

    // 최근 7일간의 완료율만 사용
    final recentData = dailyData.take(7).toList();
    if (recentData.isEmpty) return 0.75;

    final recentCompletionRates = recentData.map((day) => day['completionRate'] as double).toList();
    final averageRecentCompletion = recentCompletionRates.reduce((a, b) => a + b) / recentCompletionRates.length;

    // 일관성 보너스 (일관성이 높으면 달성 확률 증가)
    final consistencyScore = analysisData['consistencyScore'] as double;
    final finalProbability = (averageRecentCompletion * 0.8 + consistencyScore * 0.2).clamp(0.0, 1.0);

    print('🎯 실제 목표 달성 확률: ${(finalProbability*100).toInt()}% (최근 완료율: ${(averageRecentCompletion*100).toInt()}%, 일관성: ${(consistencyScore*100).toInt()}%)');

    return finalProbability;
  }

// 7. 개인화된 휴식 추천 생성
  List<String> _generatePersonalizedBreakRecommendations(Map<String, dynamic> analysisData) {
    final recommendations = <String>[];
    final hourlyData = analysisData['hourlyCompletionRates'] as Map<int, List<double>>;
    final averageDailyTasks = analysisData['averageDailyTasks'] as double;

    // 스트레스 레벨 분석
    String stressLevel = 'medium';
    if (averageDailyTasks >= 10) {
      stressLevel = 'high';
    } else if (averageDailyTasks <= 5) {
      stressLevel = 'low';
    }

    // 가장 생산성이 떨어지는 시간대 찾기 (휴식 추천 시간)
    int worstPerformanceHour = 15; // 기본값
    double worstRate = 1.0;

    hourlyData.forEach((hour, completionList) {
      if (completionList.length >= 2) {
        final averageCompletion = completionList.reduce((a, b) => a + b) / completionList.length;
        if (averageCompletion < worstRate && hour >= 13 && hour <= 17) { // 오후 시간대만
          worstRate = averageCompletion;
          worstPerformanceHour = hour;
        }
      }
    });

    // 스트레스 레벨별 맞춤 추천
    switch (stressLevel) {
      case 'high':
        recommendations.addAll([
          '오전 ${worstPerformanceHour-2}:30에 10분 명상',
          '오후 ${worstPerformanceHour}:00에 15분 산책',
          '저녁 20:00에 30분 요가나 스트레칭',
          '수면 전 독서나 음악 감상으로 마음 진정'
        ]);
        break;
      case 'low':
        recommendations.addAll([
          '오후 ${worstPerformanceHour}:00에 가벼운 티타임',
          '저녁 18:30에 산책이나 가벼운 운동',
          '자기 계발 시간 추가 확보'
        ]);
        break;
      default: // medium
        recommendations.addAll([
          '오전 10:30에 15분 휴식',
          '오후 ${worstPerformanceHour}:00에 10분 휴식',
          '저녁 식사 후 가벼운 산책'
        ]);
    }

    print('☕ 개인화 휴식 추천 (${stressLevel} 스트레스): ${recommendations.length}개');
    return recommendations;
  }

// 8. 최근 완료율 계산 함수 개선
  Future<double> _calculateRecentCompletionRate() async {
    try {
      int totalTasks = 0;
      int completedTasks = 0;

      // 최근 7일간의 실제 데이터 확인 (더 정확한 최근 성과)
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final todoTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        final allTasks = [...todoTasks, ...plannerTasks];

        totalTasks += allTasks.length;
        completedTasks += allTasks.where((task) => task.isCompleted).length;
      }

      final rate = totalTasks > 0 ? completedTasks / totalTasks : 0.8;
      print('📈 실제 최근 7일 완료율: ${(rate*100).toInt()}% ($completedTasks/$totalTasks)');
      return rate;
    } catch (e) {
      print('최근 완료율 계산 오류: $e');
      return 0.8; // 기본값
    }
  }

// 9. 생산성 점수 계산 함수 개선
  Future<double> _calculateProductivityScore() async {
    try {
      final recentCompletionRate = await _calculateRecentCompletionRate();

      // 최근 3일간의 중요 작업 완료율
      int importantTotal = 0;
      int importantCompleted = 0;

      for (int i = 0; i < 3; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final allTasks = [
          ..._taskDataService.getTodoTasksForDate(date),
          ..._taskDataService.getPlannerTasksForDate(date)
        ];

        final importantTasks = allTasks.where((task) => task.importance >= 4).toList();
        importantTotal += importantTasks.length;
        importantCompleted += importantTasks.where((task) => task.isCompleted).length;
      }

      final importantTaskRate = importantTotal > 0 ? importantCompleted / importantTotal : 1.0;

      // 일관성 점수 (최근 7일간 완료율의 일관성)
      final consistencyScore = await _calculateConsistencyScore();

      // 전체 생산성 점수 (완료율 40% + 중요작업 완료율 40% + 일관성 20%)
      final productivityScore = (recentCompletionRate * 0.4) + (importantTaskRate * 0.4) + (consistencyScore * 0.2);

      print('⚡ 실제 생산성 점수: ${(productivityScore*100).toInt()}% (완료율: ${(recentCompletionRate*100).toInt()}%, 중요작업: ${(importantTaskRate*100).toInt()}%, 일관성: ${(consistencyScore*100).toInt()}%)');
      return productivityScore.clamp(0.0, 1.0);
    } catch (e) {
      print('생산성 점수 계산 오류: $e');
      return 0.75; // 기본값
    }
  }

// 10. 일관성 점수 계산
  Future<double> _calculateConsistencyScore() async {
    try {
      final completionRates = <double>[];

      // 최근 7일간의 일별 완료율 수집
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final allTasks = [
          ..._taskDataService.getTodoTasksForDate(date),
          ..._taskDataService.getPlannerTasksForDate(date)
        ];

        if (allTasks.isNotEmpty) {
          final completed = allTasks.where((task) => task.isCompleted).length;
          final rate = completed / allTasks.length;
          completionRates.add(rate);
        }
      }

      if (completionRates.isEmpty) return 0.7;

      // 표준편차 계산으로 일관성 측정 (낮을수록 일관성 높음)
      final mean = completionRates.reduce((a, b) => a + b) / completionRates.length;
      final variance = completionRates.map((rate) => pow(rate - mean, 2)).reduce((a, b) => a + b) / completionRates.length;
      final standardDeviation = sqrt(variance);

      // 일관성 점수 (표준편차가 낮을수록 높은 점수)
      final consistencyScore = (1.0 - standardDeviation).clamp(0.0, 1.0);

      return consistencyScore;
    } catch (e) {
      print('일관성 점수 계산 오류: $e');
      return 0.7;
    }
  }

// _getUserPreferences 함수가 없다면 추가
  Future<Map<String, dynamic>> _getUserPreferences() async {
    Map<String, dynamic> preferences = {
      'preferredTimeOfDay': '아침',
      'sleepSchedule': 'PM 11:00 ~ AM 07:00',
      'breakFrequency': '1시간마다',
    };

    try {
      if (userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && userData.containsKey('preferences')) {
            final userPrefs = userData['preferences'];
            if (userPrefs is Map) {
              if (userPrefs.containsKey('preferredTimeOfDay')) {
                preferences['preferredTimeOfDay'] = userPrefs['preferredTimeOfDay'];
              }
              if (userPrefs.containsKey('sleepSchedule')) {
                preferences['sleepSchedule'] = userPrefs['sleepSchedule'];
              }
              if (userPrefs.containsKey('breakFrequency')) {
                preferences['breakFrequency'] = userPrefs['breakFrequency'];
              }
            }
          }
        }
      }
    } catch (e) {
      print('사용자 선호도 불러오기 오류: $e');
    }

    return preferences;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Calendar (Month selector) - 고정 영역
            ImprovedMonthSelector(
              selectedDate: selectedDate,
              onMonthChanged: (newDate) {
                setState(() {
                  selectedDate = newDate;
                  updateProgress();
                });
              },
            ),

            // Weekly Calendar - 고정 영역
            EnhancedWeeklyCalendar(
              selectedDate: selectedDate,
              onDateSelected: changeSelectedDate,
            ),

            // Progress Section - 플래너만 표시하도록 수정
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isPlannerView
                  ? PlannerOnlyProgressScreen(
                plannerTasks: _taskDataService.getPlannerTasksForDate(selectedDate),
                plannerProgressPercentage: plannerProgressPercentage,
              )
                  : ProgressScreen(
                tasks: _taskDataService.getTodoTasksForDate(selectedDate),
                progressPercentage: todoProgressPercentage,
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 인사이트 카드 (플래너 뷰에서만 표시)
                    if (_userInsights != null && isPlannerView)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: UserInsightsCard(insights: _userInsights!),
                      ),

                    // Header with toggle
                    _buildHeaderWithToggle(),

                    // 메인 콘텐츠 영역
                    if (isPlannerView)
                      _buildPlannerViewContent()
                    else
                      _buildTodoViewContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: BottomNav(
        initialIndex: 1,
        userId: widget.userId,
      ),
    );
  }

  Widget _buildTodoViewContent() {
    return Container(
      height: MediaQuery.of(context).size.height - 300,
      child: TodoListScreen(
        key: ValueKey(selectedDate),
        isEmbedded: true,
        initialDate: selectedDate,
        onStateCreated: (state) {
          todoListScreenState = state;
        },
        onTaskStatusChanged: () {
          updateProgress(); // 진행률 업데이트
        },
        taskDataService: _taskDataService,
        progressPercentage: todoProgressPercentage, // 투두 진행률만 전달
      ),
    );
  }



  Todo_Task _convertCalendarEventToTask(Map<String, dynamic> event) {
    return Todo_Task(
      id: event['id'] ?? 'cal_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: '${event['title'] ?? '캘린더 일정'}', // 이모지 제거
      description: event['description'] ?? '',
      time: event['startTime'],
      endTime: event['endTime'],
      date: selectedDate,
      isImportant: true,
      isUrgent: false,
      memo: event['memo'] ?? '',
      location: event['location'] ?? '',
      importance: event['importance'] ?? 5,
      urgency: event['urgency'] ?? 3,
      isCompleted: false,
      color: null,
      dueDate: null,
      notificationId: null,
      reminderMinutesBefore: null,
      isRepeating: false,
      repeatOption: null,
      repeatDays: null,
      repeatCustomDays: null,
    );
  }

  // 5. AI 추천 수락 함수 (UI에서 선택한 추천만 플래너에 추가)
  Future<void> _acceptAIRecommendation(TaskRecommendation recommendation) async {
    try {
      // AI 추천을 Todo_Task 형태로 변환
      final aiTask = Todo_Task(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${recommendation.taskId}',
        userId: userId,
        title: '🎯 ${recommendation.taskTitle}',
        description: 'AI 맞춤 추천: ${recommendation.reason}',
        time: _convertAITimeToAppFormat(recommendation.recommendedTime),
        endTime: _calculateEndTime(recommendation.recommendedTime),
        date: selectedDate,
        isImportant: recommendation.confidence >= 0.8,
        isUrgent: false,
        memo: '신뢰도: ${(recommendation.confidence * 100).toInt()}%\n${recommendation.reason}',
        location: null,
        importance: _calculateImportanceFromConfidence(recommendation.confidence),
        urgency: 2,
        isCompleted: false,
        color: null,
        dueDate: null,
        notificationId: null,
        reminderMinutesBefore: null,
        isRepeating: false,
        repeatOption: null,
        repeatDays: null,
        repeatCustomDays: null,
      );

      // 플래너에 추가
      _taskDataService.addPlannerTask(aiTask);
      await _taskDataService.savePlannerTaskToFirestore(aiTask);

      // AI 서비스 호출 부분을 로컬 처리로 대체
      try {
        // 로컬에서 사용자 행동 기록
        print('✅ AI 추천 수락: ${recommendation.taskTitle}');

        // 필요하다면 로컬 저장소에 기록
        final behaviorRecord = {
          'userId': userId,
          'taskId': recommendation.taskId,
          'taskTitle': recommendation.taskTitle,
          'action': 'accepted',
          'timestamp': DateTime.now().toIso8601String(),
          'confidence': recommendation.confidence,
          'scheduledTime': recommendation.recommendedTime,
        };

        // SharedPreferences에 행동 기록 저장 (선택사항)
        final prefs = await SharedPreferences.getInstance();
        final existingRecords = prefs.getStringList('ai_behavior_records') ?? [];
        existingRecords.add(jsonEncode(behaviorRecord));
        await prefs.setStringList('ai_behavior_records', existingRecords);

        print('사용자 행동 기록 저장 완료');
      } catch (e) {
        print('행동 기록 오류: $e');
        // 오류가 발생해도 메인 기능에는 영향 없도록 계속 진행
      }

      // 추천 목록에서 제거
      setState(() {
        _aiRecommendations.removeWhere((rec) => rec.taskId == recommendation.taskId);
        updateProgress();
      });

      _showSnackBar('${recommendation.taskTitle}이(가) ${recommendation.recommendedTime}에 추가되었습니다!');

    } catch (e) {
      print('AI 추천 수락 실패: $e');
      _showSnackBar('스케줄 적용 중 오류가 발생했습니다.');
    }
  }

// 6. AI 추천 거부 함수
  Future<void> _rejectAIRecommendation(TaskRecommendation recommendation) async {
    try {
      await _aiService.submitFeedback(
        userId: userId,
        userFeedback: 'thumbs_down',
        scheduledTasks: [
          {
            'taskId': recommendation.taskId,
            'taskTitle': recommendation.taskTitle,
            'scheduledTime': recommendation.recommendedTime,
          }
        ],
        actualFollowedSchedule: false,
        userComment: '추천 시간이 적합하지 않음',
      );

      // 추천 목록에서 제거
      setState(() {
        _aiRecommendations.removeWhere((rec) => rec.taskId == recommendation.taskId);
      });

      _showSnackBar('피드백이 기록되었습니다. 더 나은 추천을 위해 학습하겠습니다.');
    } catch (e) {
      print('AI 추천 거부 기록 실패: $e');
    }
  }

// 7. 모든 AI 추천 적용 함수
  Future<void> _applyAllAIRecommendations() async {
    if (_aiRecommendations.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple),
            SizedBox(width: 8),
            Text('모든 추천 적용'),
          ],
        ),
        content: Text('${_aiRecommendations.length}개의 AI 추천을 모두 플래너에 추가하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              int successCount = 0;
              for (final recommendation in List.from(_aiRecommendations)) {
                try {
                  await _acceptAIRecommendation(recommendation);
                  successCount++;
                  await Future.delayed(Duration(milliseconds: 100));
                } catch (e) {
                  print('개별 추천 적용 실패: $e');
                }
              }

              // 전체 피드백 제출
              await _aiService.submitFeedback(
                userId: userId,
                userFeedback: 'thumbs_up',
                scheduledTasks: _aiRecommendations.map((rec) => {
                  'taskId': rec.taskId,
                  'taskTitle': rec.taskTitle,
                  'scheduledTime': rec.recommendedTime,
                }).toList(),
                actualFollowedSchedule: true,
                userComment: '모든 추천을 수락함',
              );

              setState(() {
                _showAIRecommendations = false;
                _aiRecommendations.clear();
              });

              _showSnackBar('${successCount}개의 AI 추천이 플래너에 추가되었습니다!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text('모두 적용'),
          ),
        ],
      ),
    );
  }

// 8. AI 추천 팁 다이얼로그 (흰색 배경 + 파스텔톤 + 둥글게 개선)
  void _showAIRecommendationTipsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 25,
                offset: Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 아이콘
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE1BEE7), // 라벤더 파스텔
                        Color(0xFFF8BBD9), // 핑크 파스텔
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 36
                  ),
                ),
                SizedBox(height: 20),

                // 제목
                Text(
                  '🎯 AI 맞춤 추천 완성!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),

                // 부제목
                Text(
                  '당신의 일정을 분석해서 관련 추천을 준비했어요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7A7A7A),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),

                // 안내 사항들
                _buildPastelTipItem(
                  icon: Icons.touch_app,
                  title: '✓ 버튼으로 개별 선택',
                  description: '마음에 드는 추천만 골라서 플래너에 추가하세요',
                  color: Color(0xFFA8E6CF), // 민트 파스텔
                ),
                SizedBox(height: 18),

                _buildPastelTipItem(
                  icon: Icons.select_all,
                  title: '"모두 적용" 버튼',
                  description: '모든 추천을 한번에 플래너에 추가할 수 있어요',
                  color: Color(0xFFB8E0FF), // 스카이블루 파스텔
                ),
                SizedBox(height: 18),

                _buildPastelTipItem(
                  icon: Icons.close,
                  title: '✗ 버튼으로 거부',
                  description: '원하지 않는 추천은 거부해서 AI가 학습하도록 도와주세요',
                  color: Color(0xFFFFD3A5), // 피치 파스텔
                ),
                SizedBox(height: 28),

                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            '나중에',
                            style: TextStyle(
                              color: Color(0xFF8A8A8A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE1BEE7), // 라벤더 파스텔
                              Color(0xFFD1C4E9), // 퍼플 파스텔
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFE1BEE7).withOpacity(0.4),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.auto_fix_high, size: 20),
                          label: Text(
                            '추천 확인하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// 9. 파스텔톤 팁 아이템 위젯 (개선된 버전)
  Widget _buildPastelTipItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
                icon,
                color: Colors.white,
                size: 22
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF4A4A4A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6A6A6A),
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerViewContent() {
    // 플래너 태스크 가져오기
    final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);
    List<Todo_Task> allTasks = List.from(plannerTasks);

    // 캘린더 이벤트 강제 로드 및 추가
    _loadAndAddCalendarEvents(allTasks);

    if (allTasks.isEmpty && !_showAIRecommendations) {
      return Container(
        height: 400,
        child: const EmptyStateWidget(),
      );
    }

    // 현재 날짜와 시간 정확히 가져오기
    final now = DateTime.now();
    final currentHour = now.hour;
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // 캘린더 및 투두리스트 정보 가져오기
    _fetchCalendarAndTodoCount();

    return Column(
      children: [
        // AI 추천 섹션 (하나만)
        if (_showAIRecommendations && _aiRecommendations.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 추천 헤더 (X 버튼으로 변경)
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE8E0FF), // 더 진한 라벤더
                        Color(0xFFF0E6FF), // 더 진한 핑크
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFFD1C4E9), // 더 진한 테두리
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFE1BEE7).withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE1BEE7), // 라벤더 파스텔
                              Color(0xFFD1C4E9), // 퍼플 파스텔
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFE1BEE7).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 22
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '🎯 AI 맞춤 추천',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4A4A4A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFB3BA), // 핑크 파스텔
                                        Color(0xFFFFAFCC), // 로즈 파스텔
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_aiRecommendations.length}개의 연관 추천이 준비되었어요!',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF7A7A7A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // X 버튼 - 단순하게
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showAIRecommendations = false;
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          color: Color(0xFF8A8A8A),
                          size: 22,
                        ),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        tooltip: '숨기기',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // AI 추천 카드들
                ...(_aiRecommendations.map((recommendation) =>
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: _buildCustomAIRecommendationCard(recommendation),
                    ),
                ).toList()),

                if (_aiRecommendations.length > 1)
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 8, bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFB8E0FF), // 스카이블루 파스텔
                            Color(0xFF87CEEB), // 라이트블루 파스텔
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFB8E0FF).withOpacity(0.4),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _applyAllAIRecommendations,
                        icon: Icon(Icons.auto_fix_high, size: 20),
                        label: Text(
                          '모든 추천 적용',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 상단 정보 영역 (개수 표시)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // 캘린더 개수
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.blue.shade700),
                        SizedBox(width: 4),
                        Text(
                          '$_calendarCount Calendar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // 투두 개수
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.task_alt, size: 14, color: Colors.green.shade700),
                        SizedBox(width: 4),
                        Text(
                          '$_todoCount Task',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('일정 초기화'),
                      content: const Text('이 날짜의 모든 일정을 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _taskDataService.clearPlannerTasksForDate(selectedDate);
                            await _clearCalendarEventsForDate(selectedDate);
                            setState(() {
                              updateProgress();
                              _fetchCalendarAndTodoCount();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                tooltip: '모든 일정 삭제',
              ),
            ],
          ),
        ),

        // 시간별 일정 목록
        ...List.generate(24, (index) {
          final hour = index;
          final timeLabel = '${hour.toString().padLeft(2, '0')}:00';
          final isCurrentHour = isToday && currentHour == hour;

          // 현재 시간대에 해당하는 일정들 (플래너 + 캘린더)
          final hourTasks = allTasks.where((task) {
            if (task.time == null || task.time!.isEmpty) return false;

            try {
              // 24시간 형식 시간 처리
              if (task.time!.contains(':') && !task.time!.contains('AM') && !task.time!.contains('PM')) {
                final parts = task.time!.split(':');
                if (parts.length == 2) {
                  final taskHour = int.parse(parts[0]);
                  return taskHour == hour;
                }
              }

              // AM/PM 형식 시간 처리
              if (task.time!.contains('AM') || task.time!.contains('PM')) {
                final isPM = task.time!.contains('PM');
                final timePart = task.time!.replaceAll('AM', '').replaceAll('PM', '').trim();
                final timeParts = timePart.split(':');
                if (timeParts.length >= 1) {
                  int taskHour = int.parse(timeParts[0].trim());
                  if (isPM && taskHour < 12) taskHour += 12;
                  if (!isPM && taskHour == 12) taskHour = 0;
                  return taskHour == hour;
                }
              }
            } catch (e) {
              print('시간 파싱 오류: $e');
            }
            return false;
          }).toList();

          return Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 시간 표시
                Container(
                  width: 60,
                  constraints: BoxConstraints(minHeight: 60),
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(left: 10, top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    color: isCurrentHour
                        ? Colors.purple.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.03),
                  ),
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentHour
                          ? Colors.purple.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ),

                // 오른쪽 일정 영역
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(minHeight: 60),
                    decoration: BoxDecoration(
                      color: isCurrentHour ? Colors.purple.withOpacity(0.05) : Colors.white,
                      border: Border(
                        left: BorderSide(
                          color: isCurrentHour ? Colors.purple.shade400 : Colors.transparent,
                          width: isCurrentHour ? 3 : 0,
                        ),
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: hourTasks.isEmpty
                        ? Container() // 빈 시간대
                        : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: hourTasks.map((task) => _buildTodoTaskCard(task)).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomAIRecommendationCard(TaskRecommendation recommendation) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0E6FF), // 연보라 파스텔
            Color(0xFFE8DDFF), // 연보라 파스텔 (더 진함)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFFD1C4E9), // 더 진한 테두리
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFE1BEE7).withOpacity(0.15),
            blurRadius: 15,
            offset: Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFB39DDB), // 보라 파스텔
                      Color(0xFF9C88FF), // 보라 파스텔 (더 진함)
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFB39DDB).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 18
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.taskTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4A4A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '추천 시간: ${recommendation.recommendedTime}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A7A7A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB39DDB), // 보라 파스텔
                      Color(0xFF9C88FF), // 보라 파스텔 (더 진함)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFB39DDB).withOpacity(0.3),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${(recommendation.confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            recommendation.reason,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF5A5A5A),
              height: 1.4,
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFCE93D8), // 연보라색 적용 버튼
                        Color(0xFFBA68C8), // 연보라색 적용 버튼 (더 진함)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFCE93D8).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptAIRecommendation(recommendation),
                    icon: Icon(Icons.check, size: 18),
                    label: Text(
                      '적용',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFBDBDBD), // 회색 거부 버튼
                        Color(0xFF9E9E9E), // 회색 거부 버튼 (더 진함)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFBDBDBD).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectAIRecommendation(recommendation),
                    icon: Icon(Icons.close, size: 18),
                    label: Text(
                      '거부',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
  void _showTimePickerForRecommendation(TaskRecommendation recommendation) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(recommendation.recommendedTime.split(':')[0]),
        minute: int.parse(recommendation.recommendedTime.split(':')[1]),
      ),
    ).then((newTime) {
      if (newTime != null) {
        setState(() {
          recommendation.recommendedTime = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
        });
      }
    });
  }

  Future<void> _loadAndAddCalendarEvents(List<Todo_Task> taskList) async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in eventsSnapshot.docs) {
        try {
          final data = doc.data();
          dynamic rawStartDate = data['startDate'];
          DateTime startDate;

          if (rawStartDate is Timestamp) {
            startDate = rawStartDate.toDate();
          } else if (rawStartDate is String) {
            startDate = DateTime.parse(rawStartDate);
          } else {
            print('startDate 형식 오류: $rawStartDate');
            continue;
          }

          // 정확한 날짜 비교
          if (startDate.year == selectedDate.year &&
              startDate.month == selectedDate.month &&
              startDate.day == selectedDate.day) {

            // 이미 플래너에 있는지 확인
            bool alreadyExists = taskList.any((task) =>
            task.id == 'cal_${doc.id}' ||
                (task.title.contains(data['title'])));

            if (!alreadyExists) {
              // 캘린더 이벤트를 Todo_Task로 변환
              String? startTime;
              String? endTime;

              if (data['startTime'] != null) {
                final startTimeData = data['startTime'];
                if (startTimeData is Map<String, dynamic>) {
                  final hour = startTimeData['hour'] ?? 0;
                  final minute = startTimeData['minute'] ?? 0;
                  // 24시간 형식으로 저장 (기존 AM/PM 변환 제거)
                  startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                }
              }

              if (data['endTime'] != null) {
                final endTimeData = data['endTime'];
                if (endTimeData is Map<String, dynamic>) {
                  final hour = endTimeData['hour'] ?? 0;
                  final minute = endTimeData['minute'] ?? 0;
                  // 24시간 형식으로 저장 (기존 AM/PM 변환 제거)
                  endTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                }
              }

              final calendarTask = Todo_Task(
                id: 'cal_${doc.id}',
                userId: userId,
                title: '${data['title']}', // 이모지 제거
                description: '캘린더 일정: ${data['description'] ?? ''}',
                time: startTime,
                endTime: endTime,
                date: selectedDate,
                isImportant: true, // 캘린더 일정은 중요도 높게
                isUrgent: false,
                memo: data['memo']?.toString(),
                location: data['location']?.toString(),
                importance: 5, // 최고 중요도
                urgency: 3,
                isCompleted: false,
                color: null,
                dueDate: null,
                notificationId: null,
                reminderMinutesBefore: null,
                isRepeating: false,
                repeatOption: null,
                repeatDays: null,
                repeatCustomDays: null,
              );

              taskList.add(calendarTask);
            }
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      print('캘린더 이벤트 로드 오류: $e');
    }
  }


  Future<void> _clearCalendarEventsForDate(DateTime date) async {
    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      final dateStr = date.toIso8601String().split('T')[0];
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        if (data['startDate'] != null) {
          final eventDate = (data['startDate'] as Timestamp).toDate();
          final eventDateStr = eventDate.toIso8601String().split('T')[0];
          if (eventDateStr == dateStr) {
            batch.delete(doc.reference);
          }
        }
      }

      await batch.commit();
      print('캘린더 이벤트 삭제 완료');
    } catch (e) {
      print('캘린더 이벤트 삭제 오류: $e');
    }
  }

  Widget _buildHeaderWithToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isPlannerView
                ? (isSameDay(selectedDate, DateTime.now())
                ? 'My Today Planner'
                : 'Tasks for ${selectedDate.month}/${selectedDate.day}')
                : 'My Todo Task',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Switch(
            value: isPlannerView,
            onChanged: (value) {
              setState(() {
                isPlannerView = value;
                updateProgress();
              });
            },
            activeTrackColor: const Color(0xFFD7D0FF),
            activeColor: const Color(0xFF9D8CFF),
          ),
        ],
      ),
    );
  }



  Future<Map<String, dynamic>> _buildUserContextForAI() async {
    try {
      // 사용자 선호도 가져오기
      final userPreferences = await _getUserPreferences();

      // 최근 완료율 계산
      final recentCompletionRate = await _calculateRecentCompletionRate();

      // 생산성 점수 계산
      final productivityScore = await _calculateProductivityScore();

      // 현재 스트레스 레벨 계산
      final stressLevel = _calculateCurrentStressLevel();

      // 사용자 행동 패턴 수집
      final behaviorPatterns = await _collectUserBehaviorPatterns();

      return {
        'userId': userId,
        'sleepSchedule': userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00',
        'breakFrequency': userPreferences['breakFrequency'] ?? '1시간마다',
        'recentCompletionRate': recentCompletionRate,
        'preferredTimeOfDay': _normalizePreferredTime(userPreferences['preferredTimeOfDay'] ?? ['아침']),
        'productivityScore': productivityScore,
        'stressLevel': stressLevel,
        'focusEnvironment': userPreferences['focusEnvironment'] ?? 'quiet',
        'workStyle': userPreferences['workStyle'] ?? 'balanced',
        'currentDate': selectedDate.toIso8601String().split('T')[0],
        'dayOfWeek': selectedDate.weekday,
        'behaviorPatterns': behaviorPatterns,
        'timeZone': 'Asia/Seoul',
        'language': 'ko',
        // 추가 컨텍스트
        'currentHour': DateTime.now().hour,
        'isWeekend': selectedDate.weekday >= 6,
        'totalTasksToday': _taskDataService.getTodoTasksForDate(selectedDate).length,
      };
    } catch (e) {
      print('사용자 컨텍스트 구성 오류: $e');
      // 기본값 반환
      return {
        'userId': userId,
        'sleepSchedule': 'PM 11:00 ~ AM 07:00',
        'breakFrequency': '1시간마다',
        'recentCompletionRate': 0.8,
        'preferredTimeOfDay': ['아침'],
        'productivityScore': 0.75,
        'stressLevel': 3,
        'focusEnvironment': 'quiet',
        'workStyle': 'balanced',
        'currentDate': selectedDate.toIso8601String().split('T')[0],
        'dayOfWeek': selectedDate.weekday,
        'behaviorPatterns': {},
        'timeZone': 'Asia/Seoul',
        'language': 'ko',
        'currentHour': DateTime.now().hour,
        'isWeekend': selectedDate.weekday >= 6,
        'totalTasksToday': 0,
      };
    }
  }

// 5. 선호 시간 정규화 함수 추가
  List<String> _normalizePreferredTime(dynamic preferredTime) {
    if (preferredTime is String) {
      return [preferredTime];
    } else if (preferredTime is List) {
      return preferredTime.map((e) => e.toString()).toList();
    } else {
      return ['아침'];
    }
  }


  Future<void> _generateAISchedule() async {
    setState(() {
      _isLoadingAI = true;
      _aiRecommendationStatus = 'AI 모델 분석 중...';
    });

    try {
      print('=== 실제 AI 모델 기반 추천 시작 ===');

      // 1. 현재 플래너의 모든 일정 가져오기
      final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);
      print('현재 플래너 일정 수: ${plannerTasks.length}');

      if (plannerTasks.isEmpty) {
        setState(() {
          _isLoadingAI = false;
          _aiRecommendationStatus = '';
        });
        _showSnackBar('먼저 플래너를 생성해주세요.');
        return;
      }

      // 2. 기존 추천 초기화 (중요!)
      _aiRecommendations.clear();

      // 3. 사용자 학습 데이터 및 패턴 분석
      setState(() {
        _aiRecommendationStatus = '사용자 패턴 학습 중...';
      });

      final userLearningData = await _analyzeUserCompletionPatterns();
      final timePreferences = await _analyzeUserTimePreferences();
      final behaviorPatterns = await _collectUserBehaviorData();

      // 4. 캘린더 이벤트도 포함하여 전체 컨텍스트 구성
      final calendarEvents = await _loadCalendarEventsForAI(selectedDate);

      // 5. 현재 시간 기반 동적 추천 생성
      final currentTime = DateTime.now();
      final randomSeed = currentTime.millisecondsSinceEpoch; // 매번 다른 시드

      // 6. AI 모델용 상세 컨텍스트 구성 (시간 정보 포함)
      final aiModelContext = await _buildDynamicAIModelContext(plannerTasks, {
        'userLearningData': userLearningData,
        'timePreferences': timePreferences,
        'behaviorPatterns': behaviorPatterns,
        'calendarEvents': calendarEvents,
        'sessionInfo': {
          'date': selectedDate.toIso8601String().split('T')[0],
          'totalPlannerTasks': plannerTasks.length,
          'totalCalendarEvents': calendarEvents.length,
          'currentHour': currentTime.hour,
          'weekday': selectedDate.weekday,
          'isWeekend': selectedDate.weekday >= 6,
          'randomSeed': randomSeed, // 추천 다양성을 위한 시드
          'requestTime': currentTime.toIso8601String(),
        }
      });

      // 7. 실제 AI 모델에 추천 요청
      setState(() {
        _aiRecommendationStatus = 'AI 모델 추론 중...';
      });

      List<TaskRecommendation> aiRecommendations = [];

      try {
        // 실제 AI 서버에 요청 (다양성 옵션 포함)
        aiRecommendations = await _requestDiverseAIModelRecommendations(
          existingTasks: plannerTasks,
          userContext: aiModelContext,
          diversityLevel: 0.7, // 높은 다양성
        );

        print('✅ 실제 AI 모델 추천 성공: ${aiRecommendations.length}개');

        // 8. 추천이 부족하면 컨텍스트 기반 추천 추가
        if (aiRecommendations.length < 3) {
          final contextualRecommendations = await _generateAdvancedContextualRecommendations(
              plannerTasks,
              calendarEvents,
              maxRecommendations: 5 - aiRecommendations.length
          );
          aiRecommendations.addAll(contextualRecommendations);
        }

        // 9. 사용자 행동 패턴 업데이트 (AI 학습)
        await _updateUserLearningFromAI(aiRecommendations);

      } catch (e) {
        print('❌ AI 모델 추천 실패: $e');

        // 폴백: 향상된 컨텍스트 분석 기반 추천
        setState(() {
          _aiRecommendationStatus = '컨텍스트 분석 중...';
        });

        aiRecommendations = await _generateAdvancedContextualRecommendations(
            plannerTasks,
            calendarEvents,
            maxRecommendations: 5
        );
      }

      // 10. 추천 결과 적용
      setState(() {
        _isLoadingAI = false;
        _aiRecommendationStatus = '';
        _aiRecommendations = aiRecommendations;
        _showAIRecommendations = aiRecommendations.isNotEmpty;
      });

      if (aiRecommendations.isNotEmpty) {
        // 11. AI 추천 성공 기록
        await _recordAIRecommendationSuccess(aiRecommendations.length);

        _showSnackBar('🎯 ${aiRecommendations.length}개의 새로운 AI 맞춤 추천이 준비되었습니다!');

        // 추천 완료 팁 다이얼로그 표시
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _showAIRecommendationTipsDialog();
        }
      } else {
        _showSnackBar('현재 일정에 대한 AI 추천이 없습니다.');
      }

    } catch (e) {
      print('AI 추천 전체 프로세스 실패: $e');
      setState(() {
        _isLoadingAI = false;
        _aiRecommendationStatus = '';
      });
      _showSnackBar('AI 추천 중 오류가 발생했습니다.');
    }
  }

  Future<List<TaskRecommendation>> _requestDiverseAIModelRecommendations({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
    double diversityLevel = 0.7,
  }) async {
    try {
      const String endpoint = '/ai_recommendation';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('🤖 다양성 강화 AI 모델 추천 요청: $fullUrl');

      // 1. 기존 태스크를 AI 분석용으로 상세 변환
      final analyzedTasks = existingTasks.map((task) {
        return <String, dynamic>{
          'id': _safeString(task.id),
          'title': _safeString(task.title),
          'description': _safeString(task.description),
          'time': _safeString(task.time),
          'endTime': _safeString(task.endTime),
          'importance': _safeInt(task.importance),
          'urgency': _safeInt(task.urgency),
          'category': _safeString(_extractTaskCategory(task.title ?? '', task.description)),
          'location': _safeString(task.location),
          'memo': _safeString(task.memo),
          'isCompleted': task.isCompleted ?? false,
          'date': task.date.toIso8601String(),
          'dueDate': task.dueDate?.toIso8601String(),

          // 컨텍스트 분석을 위한 추가 메타데이터
          'semanticKeywords': _extractSemanticKeywordsSafe(task.title, task.description),
          'estimatedDuration': _safeDouble(_calculateTaskDuration(task)),
          'focusRequirement': _safeDouble(_calculateFocusRequirement(task)),
          'timeFlexibility': _safeDouble(_calculateTimeFlexibility(task)),
          'contextualRelations': _analyzeTaskRelationsSafe(task, existingTasks),
          'userHistoryMatch': _findSimilarTasksInHistorySafe(task),
          'stressIndicator': _safeDouble(_calculateTaskStressLevel(task)),
          'energyRequirement': _safeDouble(_assessEnergyRequirement(task)),
          'collaborationLevel': _safeDouble(_assessCollaborationRequirement(task)),
          'preparationNeeds': _identifyTaskPreparationNeeds(task),
        };
      }).toList();

      // 2. 다양성 강화를 위한 요청 데이터 구성
      final requestData = <String, dynamic>{
        'userId': _safeString(userContext['userId']),
        'existingTasks': analyzedTasks,
        'userContext': _sanitizeUserContextCompletely(userContext),
        'requestType': 'contextual_diverse_recommendations',
        'analysisDepth': 'deep_contextual_learning',
        'maxRecommendations': 7,
        'enableLearning': true,
        'enablePatternAnalysis': true,

        // 다양성 강화 설정
        'diversitySettings': {
          'diversityFactor': diversityLevel,
          'avoidRepetition': true,
          'exploreNewCategories': true,
          'contextualVariation': true,
          'creativityBoost': _shouldBoostCreativity(existingTasks),
          'temporalDiversity': true,
        },

        // 모델 설정
        'modelSettings': {
          'useSemanticAnalysis': true,
          'useTemporalPatterns': true,
          'useBehaviorLearning': true,
          'useStressOptimization': true,
          'useEnergyManagement': true,
          'useContextualRelations': true,
          'usePreparationAnalysis': true, // 준비사항 분석 활성화
          'confidenceThreshold': 0.6,
          'diversityWeight': 0.4, // 다양성에 높은 가중치
          'noveltyBonus': 0.2, // 새로운 추천에 보너스
        },

        // 세션 정보
        'sessionInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'timezone': 'Asia/Seoul',
          'platform': 'flutter_mobile',
          'version': '2.1.0',
          'sessionId': '${_safeString(userContext['userId'])}_${DateTime.now().millisecondsSinceEpoch}',
          'requestRound': (_aiRecommendations.length > 0) ? 'retry' : 'initial',
          'previousRecommendations': _aiRecommendations.map((r) => r.taskTitle).toList(),
        },
      };

      print('📤 다양성 강화 요청 데이터 전송');
      print('📊 분석할 태스크: ${analyzedTasks.length}개');
      print('🎯 다양성 레벨: $diversityLevel');
      print('🔄 재추천 여부: ${(_aiRecommendations.length > 0) ? 'Yes' : 'No'}');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'MomentumPlanner-AI/2.1',
          'X-Request-Type': 'diverse_contextual_recommendations',
          'X-User-Id': _safeString(userContext['userId']),
          'X-Diversity-Level': diversityLevel.toString(),
          'X-Analysis-Depth': 'deep_contextual',
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 50));

      print('📥 AI 모델 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['recommendations'] is List) {
          final List<dynamic> recommendations = responseData['recommendations'];

          final Map<String, dynamic> aiModelInfo =
          Map<String, dynamic>.from(responseData['model_info'] ?? {});
          final Map<String, dynamic> analysisMetrics =
          Map<String, dynamic>.from(responseData['analysis_metrics'] ?? {});
          final bool learningUpdate = responseData['learning_update'] ?? false;
          final double diversityScore = responseData['diversity_score']?.toDouble() ?? 0.0;

          print('✅ AI 모델 다양성 추천 성공');
          print('📊 추천 수: ${recommendations.length}개');
          print('🎯 다양성 점수: ${(diversityScore * 100).toInt()}%');

          final List<TaskRecommendation> result = [];

          for (var rec in recommendations) {
            try {
              if (rec is! Map) {
                print('❌ 추천이 Map이 아님: ${rec.runtimeType}');
                continue;
              }

              final Map<String, dynamic> recMap = Map<String, dynamic>.from(rec);

              final recommendation = TaskRecommendation(
                taskId: _safeExtractString(recMap, 'taskId') ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
                taskTitle: _safeExtractString(recMap, 'taskTitle') ?? 'AI 맞춤 추천',
                recommendedTime: _safeExtractString(recMap, 'recommendedTime') ?? '09:00',
                confidence: _safeExtractDouble(recMap, 'confidence') ?? 0.7,
                reason: _safeExtractString(recMap, 'reason') ?? 'AI 다양성 분석 기반 맞춤 추천',
                source: 'ai_model_diverse',
                createdAt: DateTime.now(),
              );

              // AI 분석 메타데이터 추가
              recommendation.aiAnalysis = {
                'semanticSimilarity': _safeExtractDouble(recMap, 'semantic_similarity') ?? 0.0,
                'temporalFit': _safeExtractDouble(recMap, 'temporal_fit') ?? 0.0,
                'userPatternMatch': _safeExtractDouble(recMap, 'user_pattern_match') ?? 0.0,
                'stressOptimization': _safeExtractDouble(recMap, 'stress_optimization') ?? 0.0,
                'energyAlignment': _safeExtractDouble(recMap, 'energy_alignment') ?? 0.0,
                'contextualRelevance': _safeExtractDouble(recMap, 'contextual_relevance') ?? 0.0,
                'diversityScore': _safeExtractDouble(recMap, 'diversity_score') ?? 0.0,
                'noveltyScore': _safeExtractDouble(recMap, 'novelty_score') ?? 0.0,
                'preparationRelevance': _safeExtractDouble(recMap, 'preparation_relevance') ?? 0.0,
              };

              recommendation.metadata = {
                'modelUsed': _safeExtractString(aiModelInfo, 'model_name') ?? 'unknown',
                'analysisTime': _safeExtractString(aiModelInfo, 'analysis_time_ms') ?? '0',
                'recommendationType': _safeExtractString(recMap, 'recommendation_type') ?? 'contextual_diverse',
                'categoryMatch': _safeExtractString(recMap, 'category_match') ?? 'general',
                'timeSlotOptimization': _safeExtractDouble(recMap, 'time_slot_optimization') ?? 0.0,
                'contextualCategory': _safeExtractString(recMap, 'contextual_category') ?? 'general',
                'preparationType': _safeExtractString(recMap, 'preparation_type') ?? 'none',
                'diversityRank': _safeExtractDouble(recMap, 'diversity_rank') ?? 0.0,
              };

              result.add(recommendation);
            } catch (e) {
              print('❌ 추천 처리 오류: $e');
            }
          }

          // 학습 업데이트가 있다면 동기화
          if (learningUpdate && responseData['updated_learning_data'] != null) {
            await _syncAILearningData(responseData['updated_learning_data']);
          }

          // 추천 품질 메트릭 기록
          final String modelInfoString = _safeExtractString(aiModelInfo, 'model_name') ??
              aiModelInfo.toString();
          await _recordDiverseRecommendationMetrics(result, modelInfoString, analysisMetrics, diversityScore);

          print('✅ 총 ${result.length}개 다양성 추천 생성 완료');
          return result;
        } else {
          throw Exception('추천 데이터 형식이 잘못됨: ${responseData['error'] ?? "알 수 없는 오류"}');
        }
      } else {
        throw Exception('서버 오류 ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ 다양성 AI 모델 요청 실패: $e');
      throw e;
    }
  }

  Future<List<TaskRecommendation>> _generateAdvancedContextualRecommendations(
      List<Todo_Task> plannerTasks,
      List<Map<String, dynamic>> calendarEvents,
      {int maxRecommendations = 5}) async {
    try {
      final recommendations = <TaskRecommendation>[];
      final occupiedHours = <int>{};
      final currentTime = DateTime.now();

      // 기존 일정 시간 수집
      for (var task in plannerTasks) {
        if (task.time != null) {
          try {
            final hour = _parseTimeToHour(task.time!);
            occupiedHours.add(hour);
          } catch (e) {}
        }
      }

      // 캘린더 이벤트 시간 수집
      for (var event in calendarEvents) {
        if (event['startTime'] != null) {
          try {
            final hour = int.parse(event['startTime'].split(':')[0]);
            occupiedHours.add(hour);
          } catch (e) {}
        }
      }

      print('🔍 고급 컨텍스트 분석 시작');
      print('점유된 시간대: $occupiedHours');

      // 플래너 일정 심층 분석
      final scheduleAnalysis = _performAdvancedScheduleAnalysis(plannerTasks, calendarEvents);
      print('📊 스케줄 분석 결과: $scheduleAnalysis');

      // 컨텍스트별 맞춤 추천 생성
      final contextualSuggestions = _generateContextBasedSuggestions(scheduleAnalysis, currentTime);

      // 시간 기반 개인화 추천 추가
      final timeBasedSuggestions = _generateTimeBasedPersonalizedSuggestions(occupiedHours, currentTime);
      contextualSuggestions.addAll(timeBasedSuggestions);

      // 생활 패턴 기반 추천 추가
      final lifestyleSuggestions = _generateLifestyleSuggestions(plannerTasks);
      contextualSuggestions.addAll(lifestyleSuggestions);

      // 중복 제거 및 다양성 확보
      final uniqueSuggestions = _ensureRecommendationDiversity(contextualSuggestions);

      // 신뢰도 및 관련성 순으로 정렬
      uniqueSuggestions.sort((a, b) {
        final aScore = ((a['confidence'] as num?)?.toDouble() ?? 0.0) *
            ((a['relevance'] as num?)?.toDouble() ?? 1.0);
        final bScore = ((b['confidence'] as num?)?.toDouble() ?? 0.0) *
            ((b['relevance'] as num?)?.toDouble() ?? 1.0);
        return bScore.compareTo(aScore);
      });

      // 최대 개수만큼 추천 생성
      for (int i = 0; i < uniqueSuggestions.length && recommendations.length < maxRecommendations; i++) {
        final suggestion = uniqueSuggestions[i];

        // preferredHours 안전하게 변환 - 여기가 문제가 되는 부분
        final preferredHoursRaw = suggestion['preferredHours'];
        List<int> preferredHours = [];

        if (preferredHoursRaw != null) {
          if (preferredHoursRaw is List) {
            preferredHours = preferredHoursRaw.map<int>((e) {
              if (e is int) return e;
              if (e is double) return e.toInt();
              if (e is String) return int.tryParse(e) ?? 9;
              return 9; // 기본값
            }).toList();
          } else {
            preferredHours = [9]; // 기본값
          }
        } else {
          preferredHours = [9]; // 기본값
        }

        // 최적 시간 찾기
        String optimalTime = '18:00';
        for (int hour in preferredHours) {
          if (!occupiedHours.contains(hour) && hour >= 6 && hour <= 22) {
            optimalTime = '${hour.toString().padLeft(2, '0')}:00';
            occupiedHours.add(hour); // 시간 점유 표시
            break;
          }
        }

        // 추천 생성
        final recommendation = TaskRecommendation(
          taskId: 'advanced_contextual_${i}_${currentTime.millisecondsSinceEpoch}',
          taskTitle: suggestion['title']?.toString() ?? 'AI 추천 작업',
          recommendedTime: optimalTime,
          confidence: (suggestion['confidence'] as num?)?.toDouble() ?? 0.5,
          reason: suggestion['reason']?.toString() ?? 'AI 기반 추천',
          source: 'advanced_contextual',
          createdAt: currentTime,
        );

        // 메타데이터 추가
        recommendation.metadata = {
          'analysisType': 'advanced_contextual',
          'contextCategory': suggestion['category']?.toString() ?? 'general',
          'relevanceScore': (suggestion['relevance'] as num?)?.toDouble() ?? 1.0,
          'preparationType': suggestion['preparationType']?.toString() ?? 'general',
          'lifestyleAlignment': (suggestion['lifestyleAlignment'] as num?)?.toDouble() ?? 0.5,
          'timeOptimization': (suggestion['timeOptimization'] as num?)?.toDouble() ?? 0.5,
        };

        recommendations.add(recommendation);
      }

      print('✅ 고급 컨텍스트 추천 생성 완료: ${recommendations.length}개');
      return recommendations;
    } catch (e) {
      print('❌ 고급 컨텍스트 추천 생성 오류: $e');
      return [];
    }
  }

// 함께 수정해야 할 _generateContextBasedSuggestions 함수
  List<Map<String, dynamic>> _generateContextBasedSuggestions(
      Map<String, dynamic> analysis, DateTime currentTime) {

    final suggestions = <Map<String, dynamic>>[];

    // themes를 안전하게 추출
    final themesRaw = analysis['dominantThemes'];
    List<String> themes = [];
    if (themesRaw is List) {
      themes = themesRaw.map((e) => e.toString()).toList();
    }

    // preparationGaps를 안전하게 추출
    final preparationGapsRaw = analysis['preparationGaps'];
    List<String> preparationGaps = [];
    if (preparationGapsRaw is List) {
      preparationGaps = preparationGapsRaw.map((e) => e.toString()).toList();
    }

    // balanceNeeds를 안전하게 추출
    final balanceNeedsRaw = analysis['balanceNeeds'];
    List<String> balanceNeeds = [];
    if (balanceNeedsRaw is List) {
      balanceNeeds = balanceNeedsRaw.map((e) => e.toString()).toList();
    }

    final urgencyLevel = analysis['urgencyLevel']?.toString() ?? 'medium';

    // 테마별 맞춤 추천
    for (var theme in themes) {
      switch (theme) {
        case '여행':
          suggestions.addAll([
            {
              'title': '여행 서류 및 준비물 최종 점검',
              'confidence': 0.95,
              'reason': '여행 일정 관련 필수 준비사항 확인',
              'category': 'travel_preparation',
              'preparationType': 'travel',
              'preferredHours': [8, 9, 19, 20],
              'relevance': 0.9,
            },
            {
              'title': '현지 정보 및 교통편 확인',
              'confidence': 0.88,
              'reason': '원활한 여행을 위한 사전 정보 수집',
              'category': 'travel_planning',
              'preparationType': 'research',
              'preferredHours': [19, 20, 21],
              'relevance': 0.85,
            },
          ]);
          break;

        case '업무':
          suggestions.addAll([
            {
              'title': '회의 효율성 향상을 위한 사전 준비',
              'confidence': 0.92,
              'reason': '생산적인 회의를 위한 체계적 준비',
              'category': 'work_preparation',
              'preparationType': 'meeting',
              'preferredHours': [8, 9, 17, 18],
              'relevance': 0.88,
            },
            {
              'title': '업무 우선순위 재점검 및 조정',
              'confidence': 0.85,
              'reason': '효율적인 업무 수행을 위한 계획 점검',
              'category': 'work_planning',
              'preparationType': 'planning',
              'preferredHours': [8, 18],
              'relevance': 0.82,
            },
          ]);
          break;

        case '건강':
          suggestions.addAll([
            {
              'title': '운동 전 컨디션 체크 및 준비',
              'confidence': 0.89,
              'reason': '안전하고 효과적인 운동을 위한 사전 준비',
              'category': 'health_preparation',
              'preparationType': 'exercise',
              'preferredHours': [7, 8, 17, 18],
              'relevance': 0.86,
            },
            {
              'title': '건강 관리 루틴 점검',
              'confidence': 0.82,
              'reason': '지속적인 건강 관리를 위한 루틴 확인',
              'category': 'health_maintenance',
              'preparationType': 'routine',
              'preferredHours': [20, 21],
              'relevance': 0.78,
            },
          ]);
          break;

        case '학습':
          suggestions.addAll([
            {
              'title': '학습 환경 최적화 및 자료 정리',
              'confidence': 0.87,
              'reason': '집중력 향상을 위한 학습 환경 조성',
              'category': 'study_preparation',
              'preparationType': 'environment',
              'preferredHours': [8, 9, 14, 15],
              'relevance': 0.84,
            },
            {
              'title': '학습 성과 점검 및 계획 수정',
              'confidence': 0.80,
              'reason': '효율적인 학습을 위한 진도 점검',
              'category': 'study_review',
              'preparationType': 'review',
              'preferredHours': [20, 21],
              'relevance': 0.76,
            },
          ]);
          break;
      }
    }

    // 긴급도 기반 추천
    if (urgencyLevel == 'high') {
      suggestions.addAll([
        {
          'title': '스트레스 관리 및 마인드 정리',
          'confidence': 0.90,
          'reason': '높은 작업량으로 인한 스트레스 완화',
          'category': 'stress_management',
          'preparationType': 'mental_health',
          'preferredHours': [12, 15, 20],
          'relevance': 0.88,
        },
        {
          'title': '우선순위 긴급 재조정',
          'confidence': 0.85,
          'reason': '급한 일정에 대한 체계적 대응',
          'category': 'priority_management',
          'preparationType': 'planning',
          'preferredHours': [8, 12],
          'relevance': 0.85,
        },
      ]);
    }

    // 균형 필요성 기반 추천
    for (var need in balanceNeeds) {
      switch (need) {
        case '개인시간':
          suggestions.add({
            'title': '개인 시간 확보 및 취미 활동',
            'confidence': 0.78,
            'reason': '일과 삶의 균형을 위한 개인 시간',
            'category': 'work_life_balance',
            'preparationType': 'personal',
            'preferredHours': [18, 19, 20, 21],
            'relevance': 0.75,
          });
          break;

        case '건강관리':
          suggestions.add({
            'title': '간단한 스트레칭 또는 건강 체크',
            'confidence': 0.82,
            'reason': '신체 건강 유지를 위한 필수 관리',
            'category': 'health_maintenance',
            'preparationType': 'health',
            'preferredHours': [11, 15, 18],
            'relevance': 0.80,
          });
          break;

        case '휴식시간':
          suggestions.add({
            'title': '짧은 휴식 및 재충전 시간',
            'confidence': 0.75,
            'reason': '지속적인 활동을 위한 에너지 보충',
            'category': 'rest_recovery',
            'preparationType': 'rest',
            'preferredHours': [13, 16, 19],
            'relevance': 0.72,
          });
          break;
      }
    }

    return suggestions;
  }


// 고급 스케줄 분석
  Map<String, dynamic> _performAdvancedScheduleAnalysis(
      List<Todo_Task> plannerTasks,
      List<Map<String, dynamic>> calendarEvents) {

    final analysis = <String, dynamic>{
      'dominantThemes': <String>[],
      'preparationGaps': <String>[],
      'balanceNeeds': <String>[],
      'stressFactors': <String>[],
      'energyDistribution': <String, int>{},
      'contextualOpportunities': <String>[],
      'timePatterns': <String, dynamic>{},
      'categoryDistribution': <String, int>{},
      'urgencyLevel': 'medium',
      'workloadDensity': 'medium',
    };

    // 모든 일정 결합 분석
    final allItems = <Map<String, dynamic>>[];

    // 플래너 태스크 추가
    for (var task in plannerTasks) {
      allItems.add({
        'title': task.title,
        'category': _getTaskType(task.title),
        'importance': task.importance,
        'urgency': task.urgency,
        'time': task.time,
        'type': 'planner',
        'keywords': _extractContextualKeywords(task.title, task.description),
      });
    }

    // 캘린더 이벤트 추가
    for (var event in calendarEvents) {
      allItems.add({
        'title': event['title'],
        'category': _inferCategoryFromTitle(event['title']),
        'importance': 5,
        'urgency': 5,
        'time': event['startTime'],
        'type': 'calendar',
        'keywords': _extractContextualKeywords(event['title'], event['description']),
      });
    }

    if (allItems.isEmpty) return analysis;

    // 테마 및 카테고리 분석
    final themes = <String>[];
    final categories = <String, int>{};
    final urgencyLevels = <int>[];

    for (var item in allItems) {
      final title = item['title'].toString().toLowerCase();
      final category = item['category'] as String;
      final keywords = item['keywords'] as String;

      // 카테고리 집계
      categories[category] = (categories[category] ?? 0) + 1;
      urgencyLevels.add(item['urgency'] as int);

      // 컨텍스트 테마 추출
      if (_containsKeywords(title, ['여행', 'travel', '항공', '출국'])) {
        themes.add('여행');
        analysis['preparationGaps'] = ['여권확인', '체크인', '짐준비', '환율확인'];
      }
      if (_containsKeywords(title, ['회의', 'meeting', '발표', 'presentation'])) {
        themes.add('업무');
        analysis['preparationGaps'] = [...(analysis['preparationGaps'] as List), '자료준비', '아젠다확인'];
      }
      if (_containsKeywords(title, ['운동', 'exercise', '헬스', 'gym'])) {
        themes.add('건강');
        analysis['preparationGaps'] = [...(analysis['preparationGaps'] as List), '운동복준비', '워밍업'];
      }
      if (_containsKeywords(title, ['공부', 'study', '학습', '수업'])) {
        themes.add('학습');
        analysis['preparationGaps'] = [...(analysis['preparationGaps'] as List), '교재준비', '환경조성'];
      }
    }

    analysis['dominantThemes'] = themes.toSet().toList();
    analysis['categoryDistribution'] = categories;

    // 긴급도 레벨 분석
    if (urgencyLevels.isNotEmpty) {
      final avgUrgency = urgencyLevels.reduce((a, b) => a + b) / urgencyLevels.length;
      if (avgUrgency >= 4) {
        analysis['urgencyLevel'] = 'high';
        analysis['stressFactors'] = ['높은_긴급도', '시간압박'];
      } else if (avgUrgency <= 2) {
        analysis['urgencyLevel'] = 'low';
        analysis['contextualOpportunities'] = ['여유시간_활용', '자기계발', '휴식'];
      }
    }

    // 작업량 밀도 분석
    if (allItems.length >= 8) {
      analysis['workloadDensity'] = 'high';
      analysis['balanceNeeds'] = ['휴식시간', '스트레스_관리'];
    } else if (allItems.length <= 3) {
      analysis['workloadDensity'] = 'low';
      analysis['contextualOpportunities'] = [...(analysis['contextualOpportunities'] as List), '추가활동', '목표설정'];
    }

    // 균형 필요성 분석
    final workCount = categories['work'] ?? 0;
    final personalCount = categories['personal'] ?? 0;
    final healthCount = categories['exercise'] ?? 0;

    final balanceNeeds = <String>[];
    if (workCount > (personalCount + healthCount) * 1.5) {
      balanceNeeds.add('개인시간');
    }
    if (healthCount == 0 && allItems.length > 3) {
      balanceNeeds.add('건강관리');
    }
    if (personalCount == 0) {
      balanceNeeds.add('휴식시간');
    }
    analysis['balanceNeeds'] = balanceNeeds;

    return analysis;
  }


// 시간 기반 개인화 추천
  List<Map<String, dynamic>> _generateTimeBasedPersonalizedSuggestions(
      Set<int> occupiedHours, DateTime currentTime) {

    final suggestions = <Map<String, dynamic>>[];
    final currentHour = currentTime.hour;

    // 아침 시간대 추천 (6-11시)
    if (!occupiedHours.contains(8) && currentHour <= 10) {
      suggestions.add({
        'title': '하루 계획 수립 및 목표 설정',
        'confidence': 0.85,
        'reason': '효율적인 하루를 위한 아침 계획 시간',
        'category': 'daily_planning',
        'preparationType': 'planning',
        'preferredHours': [8, 9],
        'relevance': 0.80,
        'timeOptimization': 0.9,
      });
    }

    // 점심 시간대 추천 (12-13시)
    if (!occupiedHours.contains(12)) {
      suggestions.add({
        'title': '오전 활동 점검 및 오후 계획 조정',
        'confidence': 0.78,
        'reason': '중간 점검을 통한 하루 일정 최적화',
        'category': 'mid_day_review',
        'preparationType': 'review',
        'preferredHours': [12, 13],
        'relevance': 0.75,
        'timeOptimization': 0.8,
      });
    }

    // 오후 시간대 추천 (14-17시)
    if (!occupiedHours.contains(15) && currentHour <= 16) {
      suggestions.add({
        'title': '오후 에너지 충전 및 집중력 회복',
        'confidence': 0.82,
        'reason': '오후 슬럼프 극복을 위한 에너지 관리',
        'category': 'energy_management',
        'preparationType': 'energy',
        'preferredHours': [15, 16],
        'relevance': 0.77,
        'timeOptimization': 0.85,
      });
    }

    // 저녁 시간대 추천 (18-21시)
    if (!occupiedHours.contains(20)) {
      suggestions.add({
        'title': '하루 마무리 및 내일 준비',
        'confidence': 0.88,
        'reason': '체계적인 하루 마무리와 다음날 준비',
        'category': 'daily_closure',
        'preparationType': 'reflection',
        'preferredHours': [20, 21],
        'relevance': 0.83,
        'timeOptimization': 0.87,
      });
    }

    return suggestions;
  }

// 생활패턴 기반 추천
  List<Map<String, dynamic>> _generateLifestyleSuggestions(List<Todo_Task> plannerTasks) {
    final suggestions = <Map<String, dynamic>>[];

    // 태스크 패턴 분석
    final categoryCount = <String, int>{};
    final timePatterns = <int, int>{};
    final stressLevel = _calculateOverallStressLevel(plannerTasks);

    for (var task in plannerTasks) {
      final category = _getTaskType(task.title);
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;

      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;
        } catch (e) {}
      }
    }

    // 생활 균형 분석 기반 추천
    final workTasks = categoryCount['work'] ?? 0;
    final personalTasks = categoryCount['personal'] ?? 0;
    final healthTasks = categoryCount['exercise'] ?? 0;
    final socialTasks = categoryCount['social'] ?? 0;

    // 과도한 업무 패턴 감지
    if (workTasks > (personalTasks + healthTasks + socialTasks)) {
      suggestions.addAll([
        {
          'title': '업무 스트레스 해소 활동',
          'confidence': 0.85,
          'reason': '업무 중심의 일정에서 벗어나 정신적 휴식 필요',
          'category': 'stress_relief',
          'preparationType': 'mental_health',
          'preferredHours': [17, 18, 19, 20],
          'relevance': 0.88,
          'lifestyleAlignment': 0.9,
        },
        {
          'title': '가족 또는 친구와의 소통 시간',
          'confidence': 0.78,
          'reason': '사회적 관계 유지를 통한 정서적 안정',
          'category': 'social_connection',
          'preparationType': 'social',
          'preferredHours': [18, 19, 20],
          'relevance': 0.82,
          'lifestyleAlignment': 0.85,
        },
      ]);
    }

    // 건강 관리 부족 패턴 감지
    if (healthTasks == 0 && plannerTasks.length > 3) {
      suggestions.addAll([
        {
          'title': '일상 속 간단한 운동 또는 산책',
          'confidence': 0.82,
          'reason': '신체 건강 유지를 위한 기본적인 신체 활동',
          'category': 'daily_exercise',
          'preparationType': 'health',
          'preferredHours': [7, 8, 17, 18, 19],
          'relevance': 0.85,
          'lifestyleAlignment': 0.88,
        },
        {
          'title': '건강한 식습관 점검 및 식단 계획',
          'confidence': 0.75,
          'reason': '균형잡힌 영양 섭취를 위한 식단 관리',
          'category': 'nutrition_planning',
          'preparationType': 'health',
          'preferredHours': [19, 20],
          'relevance': 0.78,
          'lifestyleAlignment': 0.80,
        },
      ]);
    }

    // 사회적 활동 부족 패턴 감지
    if (socialTasks == 0 && plannerTasks.length > 4) {
      suggestions.add({
        'title': '지인과의 안부 확인 또는 소통',
        'confidence': 0.72,
        'reason': '사회적 관계 유지 및 정서적 건강 증진',
        'category': 'social_maintenance',
        'preparationType': 'social',
        'preferredHours': [18, 19, 20, 21],
        'relevance': 0.75,
        'lifestyleAlignment': 0.78,
      });
    }

    // 높은 스트레스 레벨 대응
    if (stressLevel >= 0.7) {
      suggestions.addAll([
        {
          'title': '명상 또는 마음챙김 연습',
          'confidence': 0.88,
          'reason': '높은 스트레스 상황에서의 정신적 안정 도모',
          'category': 'mindfulness',
          'preparationType': 'mental_health',
          'preferredHours': [21, 22],
          'relevance': 0.90,
          'lifestyleAlignment': 0.92,
        },
        {
          'title': '스트레스 원인 분석 및 대응책 마련',
          'confidence': 0.80,
          'reason': '근본적인 스트레스 관리를 위한 체계적 접근',
          'category': 'stress_analysis',
          'preparationType': 'planning',
          'preferredHours': [20, 21],
          'relevance': 0.85,
          'lifestyleAlignment': 0.87,
        },
      ]);
    }

    // 창의성 및 자기계발 추천
    if (plannerTasks.length <= 5) { // 여유로운 일정인 경우
      suggestions.addAll([
        {
          'title': '새로운 기술 또는 지식 학습',
          'confidence': 0.75,
          'reason': '여유시간을 활용한 개인 역량 강화',
          'category': 'skill_development',
          'preparationType': 'learning',
          'preferredHours': [14, 15, 16, 19, 20],
          'relevance': 0.72,
          'lifestyleAlignment': 0.75,
        },
        {
          'title': '취미 활동 또는 창작 시간',
          'confidence': 0.70,
          'reason': '창의성 발휘 및 개인적 만족 증진',
          'category': 'creative_activity',
          'preparationType': 'creative',
          'preferredHours': [15, 16, 19, 20, 21],
          'relevance': 0.68,
          'lifestyleAlignment': 0.73,
        },
      ]);
    }

    // 시간대별 생활 패턴 최적화
    final earlyMorningTasks = timePatterns.keys.where((h) => h >= 6 && h <= 8).length;
    final lateEveningTasks = timePatterns.keys.where((h) => h >= 20 && h <= 22).length;

    if (earlyMorningTasks == 0 && plannerTasks.length > 3) {
      suggestions.add({
        'title': '아침 루틴 최적화 및 하루 준비',
        'confidence': 0.77,
        'reason': '효율적인 하루 시작을 위한 아침 시간 활용',
        'category': 'morning_routine',
        'preparationType': 'routine',
        'preferredHours': [7, 8],
        'relevance': 0.74,
        'lifestyleAlignment': 0.76,
      });
    }

    if (lateEveningTasks == 0) {
      suggestions.add({
        'title': '하루 정리 및 내면 성찰 시간',
        'confidence': 0.73,
        'reason': '의미있는 하루 마무리와 개인적 성장',
        'category': 'evening_reflection',
        'preparationType': 'reflection',
        'preferredHours': [21, 22],
        'relevance': 0.71,
        'lifestyleAlignment': 0.74,
      });
    }

    return suggestions;
  }

// 추천 다양성 확보
  List<Map<String, dynamic>> _ensureRecommendationDiversity(List<Map<String, dynamic>> suggestions) {
    final uniqueSuggestions = <Map<String, dynamic>>[];
    final seenCategories = <String>{};
    final seenPreparationTypes = <String>{};

    // 카테고리와 준비 타입의 다양성 확보
    for (var suggestion in suggestions) {
      final category = suggestion['category'] as String;
      final preparationType = suggestion['preparationType'] as String;
      final title = suggestion['title'] as String;

      // 중복 제목 체크
      final isDuplicateTitle = uniqueSuggestions.any((s) => s['title'] == title);
      if (isDuplicateTitle) continue;

      // 카테고리 다양성 체크 (같은 카테고리는 최대 2개까지)
      final categoryCount = uniqueSuggestions.where((s) => s['category'] == category).length;
      if (categoryCount >= 2) continue;

      // 준비 타입 다양성 체크 (같은 타입은 최대 2개까지)
      final preparationTypeCount = uniqueSuggestions.where((s) => s['preparationType'] == preparationType).length;
      if (preparationTypeCount >= 2) continue;

      uniqueSuggestions.add(suggestion);
      seenCategories.add(category);
      seenPreparationTypes.add(preparationType);
    }

    // 최소 다양성 보장 (다른 카테고리에서 추가)
    if (uniqueSuggestions.length < 3) {
      final additionalSuggestions = suggestions.where((s) =>
      !uniqueSuggestions.any((u) => u['title'] == s['title'])
      ).take(5 - uniqueSuggestions.length);

      uniqueSuggestions.addAll(additionalSuggestions);
    }

    return uniqueSuggestions;
  }

// 전반적 스트레스 레벨 계산
  double _calculateOverallStressLevel(List<Todo_Task> tasks) {
    if (tasks.isEmpty) return 0.0;

    double totalStress = 0.0;
    for (var task in tasks) {
      final taskStress = (task.importance + task.urgency) / 10.0;
      totalStress += taskStress;
    }

    return (totalStress / tasks.length).clamp(0.0, 1.0);
  }

// 스케줄 밀도 계산
  String _calculateScheduleDensity(List<Todo_Task> tasks) {
    final totalHours = tasks.length * 1.5; // 평균 1.5시간 가정
    if (totalHours > 12) return 'high';
    if (totalHours < 6) return 'low';
    return 'medium';
  }

// 스케줄 다양성 계산
  String _calculateScheduleVariety(List<Todo_Task> tasks) {
    final categories = tasks.map((t) => _getTaskType(t.title)).toSet();
    if (categories.length >= 4) return 'high';
    if (categories.length >= 2) return 'medium';
    return 'low';
  }

// 스케줄 균형 계산
  String _calculateScheduleBalance(List<Todo_Task> tasks) {
    final categoryCount = <String, int>{};
    for (var task in tasks) {
      final category = _getTaskType(task.title);
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    final workCount = categoryCount['work'] ?? 0;
    final personalCount = categoryCount['personal'] ?? 0;
    final healthCount = categoryCount['exercise'] ?? 0;

    final total = workCount + personalCount + healthCount;
    if (total == 0) return 'balanced';

    final balance = (workCount - (personalCount + healthCount)).abs() / total;
    if (balance <= 0.3) return 'balanced';
    if (balance <= 0.6) return 'moderately_unbalanced';
    return 'unbalanced';
  }

// 스케줄 스트레스 레벨 계산
  String _calculateScheduleStressLevel(List<Todo_Task> tasks) {
    final stressScore = _calculateOverallStressLevel(tasks);
    if (stressScore >= 0.8) return 'very_high';
    if (stressScore >= 0.6) return 'high';
    if (stressScore >= 0.4) return 'medium';
    if (stressScore >= 0.2) return 'low';
    return 'very_low';
  }

// 준비 갭 식별
  List<String> _identifyPreparationGaps(List<Todo_Task> tasks) {
    final gaps = <String>[];
    // 태스크 분석을 통한 준비 갭 식별 로직
    return gaps;
  }

// 에너지 분배 분석
  Map<String, double> _analyzeEnergyDistribution(List<Todo_Task> tasks) {
    final distribution = <String, double>{
      'morning': 0.0,
      'afternoon': 0.0,
      'evening': 0.0,
    };

    for (var task in tasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          final energy = _calculateTaskEnergyRequirement(task);

          if (hour >= 6 && hour <= 11) {
            distribution['morning'] = distribution['morning']! + energy;
          } else if (hour >= 12 && hour <= 17) {
            distribution['afternoon'] = distribution['afternoon']! + energy;
          } else if (hour >= 18 && hour <= 22) {
            distribution['evening'] = distribution['evening']! + energy;
          }
        } catch (e) {}
      }
    }

    return distribution;
  }

// 태스크 에너지 요구량 계산
  double _calculateTaskEnergyRequirement(Todo_Task task) {
    double energy = 0.5; // 기본값

    // 중요도/긴급도 기반
    energy += (task.importance + task.urgency) * 0.05;

    // 카테고리 기반 조정
    final category = _getTaskType(task.title);
    switch (category) {
      case 'work':
      case 'study':
        energy += 0.2;
        break;
      case 'exercise':
        energy += 0.3;
        break;
      case 'personal':
        energy -= 0.1;
        break;
    }

    return energy.clamp(0.1, 1.0);
  }


  // 태스크 관계 분석 개선
  Map<String, dynamic> _analyzeTaskRelationships(List<Todo_Task> tasks) {
    final relationships = <String, dynamic>{
      'sequentialTasks': <String>[],
      'parallelTasks': <String>[],
      'dependencyChains': <List<String>>[],
      'conflictingTasks': <String>[],
      'complementaryTasks': <String>[],
    };

    for (int i = 0; i < tasks.length; i++) {
      for (int j = i + 1; j < tasks.length; j++) {
        final task1 = tasks[i];
        final task2 = tasks[j];

        // 시간 충돌 분석
        if (_areTasksConflicting(task1, task2)) {
          (relationships['conflictingTasks'] as List<String>).add('${task1.title} ↔ ${task2.title}');
        }

        // 보완적 관계 분석
        if (_areTasksComplementary(task1, task2)) {
          (relationships['complementaryTasks'] as List<String>).add('${task1.title} + ${task2.title}');
        }
      }
    }

    return relationships;
  }

// 시간적 컨텍스트 상세 분석
  Map<String, dynamic> _analyzeTemporalContextDetailed() {
    final now = DateTime.now();
    final selectedDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return {
      'timeOfDay': _getDetailedTimeOfDay(now.hour),
      'dayPhase': _getDayPhase(now.hour),
      'weekPosition': _getWeekPosition(selectedDate.weekday),
      'monthPosition': _getMonthPosition(selectedDate.day),
      'seasonalContext': _getSeasonalContext(now.month),
      'isWorkingDay': selectedDate.weekday <= 5,
      'daysSinceWeekStart': selectedDate.weekday - 1,
      'daysUntilWeekend': selectedDate.weekday <= 5 ? 6 - selectedDate.weekday : 0,
      'relativeToToday': selectedDateTime.difference(DateTime(now.year, now.month, now.day)).inDays,
    };
  }

// 상세 가용 시간 창 계산
  List<Map<String, dynamic>> _getDetailedAvailableTimeWindows(List<Todo_Task> tasks) {
    final occupiedSlots = <int, Map<String, dynamic>>{};

    // 점유된 시간 상세 분석
    for (var task in tasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          occupiedSlots[hour] = {
            'taskTitle': task.title,
            'importance': task.importance,
            'urgency': task.urgency,
            'flexibility': _calculateTimeFlexibility(task),
          };
        } catch (e) {}
      }
    }

    final windows = <Map<String, dynamic>>[];
    int windowStart = -1;

    for (int hour = 6; hour <= 23; hour++) {
      if (!occupiedSlots.containsKey(hour)) {
        if (windowStart == -1) windowStart = hour;
      } else {
        if (windowStart != -1) {
          windows.add({
            'startHour': windowStart,
            'endHour': hour - 1,
            'duration': hour - windowStart,
            'quality': _assessTimeWindowQuality(windowStart, hour - 1),
            'energyLevel': _getExpectedEnergyLevel(windowStart),
            'suitableFor': _getSuitableActivityTypes(windowStart, hour - 1),
          });
          windowStart = -1;
        }
      }
    }

    // 마지막 윈도우 처리
    if (windowStart != -1) {
      windows.add({
        'startHour': windowStart,
        'endHour': 23,
        'duration': 24 - windowStart,
        'quality': _assessTimeWindowQuality(windowStart, 23),
        'energyLevel': _getExpectedEnergyLevel(windowStart),
        'suitableFor': _getSuitableActivityTypes(windowStart, 23),
      });
    }

    return windows;
  }

// 남은 에너지 예산 계산
  double _calculateRemainingEnergyBudget() {
    final now = DateTime.now();
    final hoursLeft = 22 - now.hour; // 밤 10시까지
    final currentEnergyLevel = _estimateCurrentEnergyLevel();

    // 시간대별 에너지 감소율 고려
    double energyBudget = 0.0;
    for (int i = 0; i < hoursLeft; i++) {
      final futureHour = now.hour + i;
      final hourlyEnergy = _getExpectedEnergyLevel(futureHour);
      energyBudget += hourlyEnergy * 0.8; // 80% 효율성 가정
    }

    return energyBudget.clamp(0.0, 10.0);
  }

// 스트레스 임계점 계산
  double _calculateStressThreshold(List<Todo_Task> tasks) {
    final baseStressLevel = _calculateOverallStressLevel(tasks);
    final taskCount = tasks.length;

    // 기본 임계점에서 현재 스트레스와 작업량 고려
    double threshold = 0.7; // 기본 임계점

    if (baseStressLevel > 0.6) threshold -= 0.1; // 이미 스트레스가 높으면 임계점 낮춤
    if (taskCount > 8) threshold -= 0.1; // 작업이 많으면 임계점 낮춤
    if (taskCount < 3) threshold += 0.1; // 작업이 적으면 임계점 높임

    return threshold.clamp(0.3, 0.9);
  }

// 집중 용량 추정
  double _estimateFocusCapacity() {
    final now = DateTime.now();
    final hour = now.hour;

    // 시간대별 기본 집중력
    double baseFocus = 1.0;
    if (hour >= 9 && hour <= 11) baseFocus = 1.0; // 오전 최고
    else if (hour >= 14 && hour <= 16) baseFocus = 0.9; // 오후 좋음
    else if (hour >= 19 && hour <= 21) baseFocus = 0.7; // 저녁 보통
    else baseFocus = 0.5; // 기타 시간

    // 요일별 조정
    if (selectedDate.weekday == 1) baseFocus *= 0.9; // 월요일은 약간 낮음
    if (selectedDate.weekday >= 6) baseFocus *= 0.8; // 주말은 낮음

    return baseFocus;
  }

// 태스크 충돌 확인
  bool _areTasksConflicting(Todo_Task task1, Todo_Task task2) {
    if (task1.time == null || task2.time == null) return false;

    try {
      final hour1 = _parseTimeToHour(task1.time!);
      final hour2 = _parseTimeToHour(task2.time!);

      // 같은 시간이거나 1시간 차이면 충돌
      return (hour1 - hour2).abs() <= 1;
    } catch (e) {
      return false;
    }
  }

// 태스크 보완성 확인
  bool _areTasksComplementary(Todo_Task task1, Todo_Task task2) {
    final category1 = _getTaskType(task1.title);
    final category2 = _getTaskType(task2.title);

    // 보완적 카테고리 조합
    final complementaryPairs = [
      ['work', 'exercise'], // 업무 후 운동
      ['study', 'exercise'], // 공부 후 운동
      ['work', 'personal'], // 업무 후 개인시간
      ['meeting', 'planning'], // 회의 후 계획
    ];

    return complementaryPairs.any((pair) =>
    (pair[0] == category1 && pair[1] == category2) ||
        (pair[0] == category2 && pair[1] == category1)
    );
  }

// 상세 시간대 분류
  String _getDetailedTimeOfDay(int hour) {
    if (hour >= 5 && hour <= 7) return 'early_morning';
    if (hour >= 8 && hour <= 11) return 'morning';
    if (hour >= 12 && hour <= 13) return 'midday';
    if (hour >= 14 && hour <= 17) return 'afternoon';
    if (hour >= 18 && hour <= 20) return 'early_evening';
    if (hour >= 21 && hour <= 23) return 'evening';
    return 'night';
  }

// 하루 단계 분류
  String _getDayPhase(int hour) {
    if (hour >= 6 && hour <= 12) return 'ascending';
    if (hour >= 13 && hour <= 18) return 'peak';
    if (hour >= 19 && hour <= 23) return 'descending';
    return 'rest';
  }

// 계절적 컨텍스트
  Map<String, dynamic> _getSeasonalContext(int month) {
    String season;
    double energyModifier;
    List<String> characteristics;

    if (month >= 3 && month <= 5) {
      season = 'spring';
      energyModifier = 1.1;
      characteristics = ['renewal', 'growth', 'optimism'];
    } else if (month >= 6 && month <= 8) {
      season = 'summer';
      energyModifier = 1.2;
      characteristics = ['energy', 'activity', 'social'];
    } else if (month >= 9 && month <= 11) {
      season = 'autumn';
      energyModifier = 0.9;
      characteristics = ['reflection', 'preparation', 'focus'];
    } else {
      season = 'winter';
      energyModifier = 0.8;
      characteristics = ['introspection', 'planning', 'rest'];
    }

    return {
      'season': season,
      'energyModifier': energyModifier,
      'characteristics': characteristics,
    };
  }

// 시간 창 품질 평가
  double _assessTimeWindowQuality(int startHour, int endHour) {
    double quality = 0.5; // 기본값

    // 최적 시간대 보너스
    if (startHour >= 9 && endHour <= 11) quality += 0.3; // 오전 최고
    if (startHour >= 14 && endHour <= 16) quality += 0.2; // 오후 좋음

    // 길이 보너스
    final duration = endHour - startHour + 1;
    if (duration >= 2) quality += 0.1;
    if (duration >= 3) quality += 0.1;

    // 연속성 보너스
    if (duration >= 2) quality += 0.1;

    return quality.clamp(0.1, 1.0);
  }

// 예상 에너지 레벨
  double _getExpectedEnergyLevel(int hour) {
    // 일반적인 생체리듬 곡선
    if (hour >= 6 && hour <= 8) return 0.7;
    if (hour >= 9 && hour <= 11) return 1.0; // 오전 피크
    if (hour >= 12 && hour <= 13) return 0.6; // 점심 시간
    if (hour >= 14 && hour <= 16) return 0.9; // 오후 피크
    if (hour >= 17 && hour <= 19) return 0.7;
    if (hour >= 20 && hour <= 22) return 0.5;
    return 0.3; // 늦은 시간
  }

// 적합한 활동 타입
  List<String> _getSuitableActivityTypes(int startHour, int endHour) {
    final types = <String>[];

    if (startHour >= 8 && startHour <= 11) {
      types.addAll(['planning', 'high_focus', 'important_tasks']);
    }
    if (startHour >= 12 && startHour <= 13) {
      types.addAll(['light_tasks', 'review', 'social']);
    }
    if (startHour >= 14 && startHour <= 17) {
      types.addAll(['creative', 'collaborative', 'medium_focus']);
    }
    if (startHour >= 18 && startHour <= 21) {
      types.addAll(['personal', 'reflection', 'light_exercise']);
    }

    // 긴 시간창인 경우
    if ((endHour - startHour) >= 2) {
      types.addAll(['deep_work', 'project_work', 'learning']);
    }

    return types.isEmpty ? ['general'] : types;
  }


// 태스크 준비사항 분석
  List<String> _identifyTaskPreparationNeeds(Todo_Task task) {
    final needs = <String>[];
    final title = task.title.toLowerCase();
    final description = (task.description ?? '').toLowerCase();
    final combined = '$title $description';

    // 여행 관련 준비사항
    if (_containsKeywords(combined, ['여행', 'travel', '항공', '출국', '비행기'])) {
      needs.addAll(['여권확인', '체크인', '짐준비', '환율확인', '보험확인']);
    }

    // 회의 관련 준비사항
    if (_containsKeywords(combined, ['회의', 'meeting', '미팅', '발표'])) {
      needs.addAll(['자료준비', '아젠다확인', '참석자확인', '장소확인']);
    }

    // 운동 관련 준비사항
    if (_containsKeywords(combined, ['운동', 'exercise', '헬스', 'gym'])) {
      needs.addAll(['운동복준비', '물준비', '워밍업', '장비확인']);
    }

    // 공부 관련 준비사항
    if (_containsKeywords(combined, ['공부', 'study', '학습', '수업'])) {
      needs.addAll(['교재준비', '필기도구', '환경조성', '복습자료']);
    }

    // 의료 관련 준비사항
    if (_containsKeywords(combined, ['병원', '의료', '검진', '치료'])) {
      needs.addAll(['보험증준비', '신분증확인', '증상정리', '약물리스트']);
    }

    // 쇼핑 관련 준비사항
    if (_containsKeywords(combined, ['쇼핑', 'shopping', '구매', '마트'])) {
      needs.addAll(['리스트작성', '예산계획', '할인정보', '교통편확인']);
    }

    return needs;
  }

  // 다양성 추천 메트릭 기록
  Future<void> _recordDiverseRecommendationMetrics(
      List<TaskRecommendation> recommendations,
      String method,
      Map<String, dynamic> analysisMetrics,
      double diversityScore,
      ) async {
    try {
      final qualityMetrics = {
        'userId': userId,
        'date': selectedDate.toIso8601String().split('T')[0],
        'method': method,
        'recommendationCount': recommendations.length,
        'diversityScore': diversityScore,
        'averageConfidence': recommendations
            .map((r) => r.confidence)
            .reduce((a, b) => a + b) /
            recommendations.length,
        'confidenceDistribution': {
          'high': recommendations.where((r) => r.confidence >= 0.8).length,
          'medium': recommendations
              .where((r) => r.confidence >= 0.6 && r.confidence < 0.8)
              .length,
          'low': recommendations.where((r) => r.confidence < 0.6).length,
        },
        'categories': recommendations
            .map((r) => _inferCategoryFromTitle(r.taskTitle))
            .toSet()
            .toList(),
        'noveltyDistribution': {
          'high': recommendations.where((r) {
            final novelty = r.aiAnalysis?['noveltyScore'] ?? 0.0;
            return novelty >= 0.7;
          }).length,
          'medium': recommendations.where((r) {
            final novelty = r.aiAnalysis?['noveltyScore'] ?? 0.0;
            return novelty >= 0.4 && novelty < 0.7;
          }).length,
          'low': recommendations.where((r) {
            final novelty = r.aiAnalysis?['noveltyScore'] ?? 0.0;
            return novelty < 0.4;
          }).length,
        },
        'preparationRelevance': recommendations
            .map((r) => r.aiAnalysis?['preparationRelevance'] ?? 0.0)
            .reduce((a, b) => a + b) /
            recommendations.length,
        'analysisMetrics': analysisMetrics,
        'timestamp': FieldValue.serverTimestamp(),
        'requestType': 'diverse_contextual',
      };

      await FirebaseFirestore.instance
          .collection('ai_recommendation_metrics')
          .add(qualityMetrics);

      print('📊 다양성 추천 메트릭 기록 완료 - 다양성: ${(diversityScore * 100).toInt()}%');
    } catch (e) {
      print('❌ 다양성 메트릭 기록 오류: $e');
    }
  }


  Future<Map<String, dynamic>> _buildDynamicAIModelContext(
      List<Todo_Task> existingTasks,
      Map<String, dynamic> additionalData
      ) async {
    try {
      print('🧠 동적 AI 모델 컨텍스트 구성 시작');

      // 기본 사용자 정보
      final userPreferences = await _getUserPreferences();
      final currentTime = DateTime.now();

      // 플래너 일정 심층 분석
      final plannerAnalysis = _analyzePlannerForRecommendations(existingTasks);

      // 최근 완료 패턴 동적 분석
      final recentPatterns = await _analyzeDynamicUserPatterns();

      final aiContext = <String, dynamic>{
        // 기본 정보
        'userId': userId,
        'currentDate': selectedDate.toIso8601String().split('T')[0],
        'currentTime': currentTime.toIso8601String(),
        'timezone': 'Asia/Seoul',
        'language': 'ko',
        'dayOfWeek': selectedDate.weekday,
        'isWeekend': selectedDate.weekday >= 6,
        'requestTimestamp': currentTime.millisecondsSinceEpoch,

        // 동적 세션 정보
        'sessionInfo': {
          ...additionalData['sessionInfo'],
          'analysisDepth': 'contextual_deep',
          'diversityRequested': true,
          'previousRecommendationCount': _aiRecommendations.length,
        },

        // 플래너 분석 결과
        'plannerAnalysis': plannerAnalysis,

        // 사용자 학습 데이터
        'userLearningData': additionalData['userLearningData'] ?? {},
        'timePreferences': additionalData['timePreferences'] ?? {},
        'behaviorPatterns': additionalData['behaviorPatterns'] ?? {},
        'recentPatterns': recentPatterns,

        // 컨텍스트 분석
        'contextAnalysis': await _analyzeCurrentScheduleContext(existingTasks),
        'taskRelationships': _analyzeTaskRelationships(existingTasks),
        'temporalContext': _analyzeTemporalContextDetailed(),

        // AI 모델 설정 (다양성 강화)
        'aiSettings': {
          'recommendationStyle': 'contextual_diverse',
          'learningEnabled': true,
          'adaptationLevel': recentPatterns['adaptationLevel'] ?? 0.5,
          'diversityFactor': 0.8, // 높은 다양성
          'creativityBoost': _shouldBoostCreativity(existingTasks),
          'socialBalance': _needsSocialBalance(existingTasks),
          'productivityOptimization': true,
        },

        // 제약 조건 및 목표
        'constraints': {
          'availableTimeWindows': _getDetailedAvailableTimeWindows(existingTasks),
          'energyBudget': _calculateRemainingEnergyBudget(),
          'stressThreshold': _calculateStressThreshold(existingTasks),
          'focusCapacity': _estimateFocusCapacity(),
        },

        // 추천 목표
        'recommendationGoals': {
          'enhanceProductivity': true,
          'reduceStress': _needsStressReduction(existingTasks),
          'improveBalance': _needsWorkLifeBalance(existingTasks),
          'supportGoals': _identifyActiveGoals(existingTasks),
          'preparationTasks': _identifyPreparationNeeds(existingTasks),
        },

        // 메타데이터
        'metadata': {
          'analysisVersion': '2.0',
          'qualityScore': _calculateContextQualityScore(),
          'confidenceLevel': _calculateAnalysisConfidenceLevel(),
          'dataCompleteness': _assessDataCompleteness(),
        },
      };

      print('🧠 동적 AI 모델 컨텍스트 구성 완료');
      return aiContext;

    } catch (e) {
      print('❌ 동적 AI 모델 컨텍스트 구성 오류: $e');
      return await _buildBasicAIContext(existingTasks);
    }
  }

// 플래너 분석 함수
  Map<String, dynamic> _analyzePlannerForRecommendations(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'taskCategories': <String, List<String>>{},
      'timeGaps': <Map<String, dynamic>>[],
      'preparationOpportunities': <Map<String, dynamic>>[],
      'complementaryNeeds': <String>[],
      'contextualThemes': <String>[],
      'stressPoints': <Map<String, dynamic>>[],
      'balanceNeeds': <String>[],
    };

    if (tasks.isEmpty) return analysis;

    // 카테고리별 태스크 그룹화
    final categoryGroups = <String, List<Todo_Task>>{};
    final themes = <String>[];
    final preparationNeeds = <String>[];

    for (var task in tasks) {
      final category = _getTaskType(task.title);
      if (!categoryGroups.containsKey(category)) {
        categoryGroups[category] = [];
      }
      categoryGroups[category]!.add(task);

      final title = task.title.toLowerCase();
      final description = (task.description ?? '').toLowerCase();
      final combined = '$title $description';

      // 테마 및 준비 사항 식별
      if (_containsKeywords(combined, ['여행', 'travel', '항공', '출국'])) {
        themes.add('여행');
        preparationNeeds.addAll(['여권확인', '항공체크인', '짐준비', '환율확인']);
      }
      if (_containsKeywords(combined, ['회의', 'meeting', '발표', 'presentation'])) {
        themes.add('업무');
        preparationNeeds.addAll(['자료준비', '아젠다확인', '참석자확인']);
      }
      if (_containsKeywords(combined, ['운동', 'exercise', '헬스', 'gym'])) {
        themes.add('건강');
        preparationNeeds.addAll(['운동복준비', '워밍업', '물준비']);
      }
      if (_containsKeywords(combined, ['공부', 'study', '학습', '수업'])) {
        themes.add('학습');
        preparationNeeds.addAll(['교재준비', '환경조성', '복습']);
      }
    }

    analysis['contextualThemes'] = themes.toSet().toList();
    analysis['preparationOpportunities'] = preparationNeeds.toSet()
        .map((need) => {
      'type': need,
      'relevance': 0.8,
      'urgency': 'medium'
    }).toList();

    // 시간 갭 분석
    final occupiedHours = <int>{};
    for (var task in tasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          occupiedHours.add(hour);
        } catch (e) {}
      }
    }

    final timeGaps = <Map<String, dynamic>>[];
    for (int hour = 8; hour <= 20; hour++) {
      if (!occupiedHours.contains(hour)) {
        timeGaps.add({
          'startHour': hour,
          'duration': 1,
          'suitability': _getTimeSuitabilityScore(hour),
          'recommendedFor': _getRecommendedActivityType(hour),
        });
      }
    }
    analysis['timeGaps'] = timeGaps;

    // 균형 필요성 분석
    final balanceNeeds = <String>[];
    final workCount = categoryGroups['work']?.length ?? 0;
    final personalCount = categoryGroups['personal']?.length ?? 0;
    final healthCount = categoryGroups['exercise']?.length ?? 0;

    if (workCount > personalCount * 2) balanceNeeds.add('개인시간');
    if (healthCount == 0) balanceNeeds.add('건강관리');
    if (personalCount == 0) balanceNeeds.add('휴식시간');

    analysis['balanceNeeds'] = balanceNeeds;

    return analysis;
  }

// 동적 사용자 패턴 분석
  Future<Map<String, dynamic>> _analyzeDynamicUserPatterns() async {
    final patterns = <String, dynamic>{
      'adaptationLevel': 0.5,
      'preferredCategories': <String>[],
      'avoidedTimeSlots': <int>[],
      'productivityWindows': <int>[],
      'recentSuccessRate': 0.0,
      'improvementTrend': 0.0,
    };

    try {
      // 최근 7일간의 완료 패턴 분석
      final recentCompletions = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dayTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        final allTasks = [...dayTasks, ...plannerTasks];

        if (allTasks.isNotEmpty) {
          final completed = allTasks.where((t) => t.isCompleted).length;
          final total = allTasks.length;
          recentCompletions.add({
            'date': date,
            'completionRate': completed / total,
            'totalTasks': total,
          });
        }
      }

      if (recentCompletions.isNotEmpty) {
        final avgRate = recentCompletions
            .map((r) => r['completionRate'] as double)
            .reduce((a, b) => a + b) / recentCompletions.length;
        patterns['recentSuccessRate'] = avgRate;
        patterns['adaptationLevel'] = avgRate;
      }

      return patterns;
    } catch (e) {
      print('동적 패턴 분석 오류: $e');
      return patterns;
    }
  }

// 현재 스케줄 컨텍스트 분석
  Future<Map<String, dynamic>> _analyzeCurrentScheduleContext(List<Todo_Task> tasks) async {
    return {
      'density': _calculateScheduleDensity(tasks),
      'variety': _calculateScheduleVariety(tasks),
      'balance': _calculateScheduleBalance(tasks),
      'stress_level': _calculateScheduleStressLevel(tasks),
      'preparation_gaps': _identifyPreparationGaps(tasks),
      'energy_distribution': _analyzeEnergyDistribution(tasks),
    };
  }

// 헬퍼 함수들
  double _getTimeSuitabilityScore(int hour) {
    if (hour >= 9 && hour <= 11) return 0.9; // 아침 최적
    if (hour >= 14 && hour <= 16) return 0.8; // 오후 좋음
    if (hour >= 19 && hour <= 21) return 0.7; // 저녁 괜찮음
    return 0.5; // 기타
  }

  String _getRecommendedActivityType(int hour) {
    if (hour >= 8 && hour <= 10) return 'planning';
    if (hour >= 11 && hour <= 13) return 'focus_work';
    if (hour >= 14 && hour <= 16) return 'creative';
    if (hour >= 17 && hour <= 19) return 'social';
    if (hour >= 20 && hour <= 22) return 'reflection';
    return 'general';
  }

  bool _shouldBoostCreativity(List<Todo_Task> tasks) {
    return tasks.any((t) =>
    t.title.toLowerCase().contains('창작') ||
        t.title.toLowerCase().contains('기획') ||
        t.title.toLowerCase().contains('디자인')
    );
  }

  bool _needsSocialBalance(List<Todo_Task> tasks) {
    final individualTasks = tasks.where((t) =>
    !t.title.toLowerCase().contains('회의') &&
        !t.title.toLowerCase().contains('만남')
    ).length;
    return individualTasks >= 5;
  }

  bool _needsStressReduction(List<Todo_Task> tasks) {
    final highStressTasks = tasks.where((t) =>
    t.importance >= 4 || t.urgency >= 4
    ).length;
    return highStressTasks >= 3;
  }

  bool _needsWorkLifeBalance(List<Todo_Task> tasks) {
    final workTasks = tasks.where((t) =>
    _getTaskType(t.title) == 'work'
    ).length;
    return workTasks > tasks.length * 0.7;
  }

  List<String> _identifyActiveGoals(List<Todo_Task> tasks) {
    final goals = <String>[];
    // 태스크 분석을 통한 목표 식별 로직
    return goals;
  }

  List<String> _identifyPreparationNeeds(List<Todo_Task> tasks) {
    final needs = <String>[];
    // 태스크 기반 준비 사항 식별
    return needs;
  }

  double _calculateContextQualityScore() => 0.8;
  double _calculateAnalysisConfidenceLevel() => 0.75;
  double _assessDataCompleteness() => 0.7;



  Future<List<TaskRecommendation>> _requestRealAIModelRecommendations({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      const String endpoint = '/ai_recommendation';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('🤖 실제 AI 모델 추천 요청: $fullUrl');

      final detailedTasks = existingTasks.map((task) {
        return <String, dynamic>{
          'id': _safeString(task.id),
          'title': _safeString(task.title),
          'description': _safeString(task.description),
          'time': _safeString(task.time),
          'endTime': _safeString(task.endTime),
          'importance': _safeInt(task.importance),
          'urgency': _safeInt(task.urgency),
          'category': _safeString(_extractTaskCategory(task.title ?? '', task.description)),
          'location': _safeString(task.location),
          'memo': _safeString(task.memo),
          'isCompleted': task.isCompleted ?? false,
          'date': task.date.toIso8601String(),
          'dueDate': task.dueDate?.toIso8601String(),
          'semanticKeywords': _extractSemanticKeywordsSafe(task.title, task.description),
          'estimatedDuration': _safeDouble(_calculateTaskDuration(task)),
          'focusRequirement': _safeDouble(_calculateFocusRequirement(task)),
          'timeFlexibility': _safeDouble(_calculateTimeFlexibility(task)),
          'contextualRelations': _analyzeTaskRelationsSafe(task, existingTasks),
          'userHistoryMatch': _findSimilarTasksInHistorySafe(task),
          'stressIndicator': _safeDouble(_calculateTaskStressLevel(task)),
          'energyRequirement': _safeDouble(_assessEnergyRequirement(task)),
          'collaborationLevel': _safeDouble(_assessCollaborationRequirement(task)),
        };
      }).toList();

      final safeUserContext = _sanitizeUserContextCompletely(userContext);

      final requestData = <String, dynamic>{
        'userId': _safeString(safeUserContext['userId']),
        'existingTasks': detailedTasks,
        'userContext': safeUserContext,
        'requestType': 'intelligent_contextual_analysis',
        'analysisDepth': 'deep_learning',
        'maxRecommendations': 7,
        'enableLearning': true,
        'enablePatternAnalysis': true,
        'modelSettings': {
          'useSemanticAnalysis': true,
          'useTemporalPatterns': true,
          'useBehaviorLearning': true,
          'useStressOptimization': true,
          'useEnergyManagement': true,
          'useContextualRelations': true,
          'confidenceThreshold': 0.6,
          'diversityFactor': 0.3,
        },
        'sessionInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'timezone': 'Asia/Seoul',
          'platform': 'flutter_mobile',
          'version': '2.0.0',
          'sessionId': '${_safeString(safeUserContext['userId'])}_${DateTime.now().millisecondsSinceEpoch}',
        },
      };

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'MomentumPlanner-AI/2.0',
          'X-Request-Type': 'ai_model_inference',
          'X-User-Id': _safeString(safeUserContext['userId']),
          'X-Analysis-Depth': 'deep_learning',
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 45));

      print('📥 AI 모델 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['recommendations'] is List) {
          final List<dynamic> recommendations = responseData['recommendations'];

          final Map<String, dynamic> aiModelInfo =
          Map<String, dynamic>.from(responseData['model_info'] ?? {});
          final Map<String, dynamic> analysisMetrics =
          Map<String, dynamic>.from(responseData['analysis_metrics'] ?? {});
          final bool learningUpdate = responseData['learning_update'] ?? false;

          print('✅ AI 모델 추천 성공');

          final List<TaskRecommendation> result = [];

          for (var rec in recommendations) {
            try {
              if (rec is! Map) {
                print('❌ 추천이 Map이 아님: ${rec.runtimeType}');
                continue;
              }

              final Map<String, dynamic> recMap = Map<String, dynamic>.from(rec);

              final recommendation = TaskRecommendation(
                taskId: _safeExtractString(recMap, 'taskId') ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
                taskTitle: _safeExtractString(recMap, 'taskTitle') ?? 'AI 맞춤 추천',
                recommendedTime: _safeExtractString(recMap, 'recommendedTime') ?? '09:00',
                confidence: _safeExtractDouble(recMap, 'confidence') ?? 0.7,
                reason: _safeExtractString(recMap, 'reason') ?? 'AI 모델 분석 결과',
                source: 'ai_model',
                createdAt: DateTime.now(),
              );

              recommendation.aiAnalysis = {
                'semanticSimilarity': _safeExtractDouble(recMap, 'semantic_similarity') ?? 0.0,
                'temporalFit': _safeExtractDouble(recMap, 'temporal_fit') ?? 0.0,
                'userPatternMatch': _safeExtractDouble(recMap, 'user_pattern_match') ?? 0.0,
                'stressOptimization': _safeExtractDouble(recMap, 'stress_optimization') ?? 0.0,
                'energyAlignment': _safeExtractDouble(recMap, 'energy_alignment') ?? 0.0,
                'contextualRelevance': _safeExtractDouble(recMap, 'contextual_relevance') ?? 0.0,
                'learningWeight': _safeExtractDouble(recMap, 'learning_weight') ?? 0.0,
                'modelConfidence': _safeExtractDouble(recMap, 'model_confidence') ?? 0.0,
              };

              recommendation.metadata = {
                'modelUsed': _safeExtractString(aiModelInfo, 'model_name') ?? 'unknown',
                'analysisTime': _safeExtractString(aiModelInfo, 'analysis_time_ms') ?? '0',
                'recommendationType': _safeExtractString(recMap, 'recommendation_type') ?? 'contextual',
                'categoryMatch': _safeExtractString(recMap, 'category_match') ?? 'general',
                'timeSlotOptimization': _safeExtractDouble(recMap, 'time_slot_optimization') ?? 0.0,
              };

              result.add(recommendation);
            } catch (e) {
              print('❌ 추천 처리 오류: $e');
            }
          }

          if (learningUpdate && responseData['updated_learning_data'] != null) {
            await _syncAILearningData(responseData['updated_learning_data']);
          }

          // 🔥 aiModelInfo에서 문자열 추출해서 전달
          final String modelInfoString = _safeExtractString(aiModelInfo, 'model_name') ??
              aiModelInfo.toString();
          await _recordAIRecommendationMetrics(result, modelInfoString, analysisMetrics);

          print('✅ 총 ${result.length}개 추천 생성 완료');
          return result;
        } else {
          throw Exception('추천 데이터 형식이 잘못됨');
        }
      } else {
        throw Exception('서버 오류 ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ 실제 AI 모델 요청 실패: $e');
      throw e;
    }
  }


// 안전한 추출 함수들
  String? _safeExtractString(Map<String, dynamic> map, String key) {
    try {
      final value = map[key];
      if (value == null) return null;

      if (value is String) {
        return value;
      }

      if (value is Map) {
        print('⚠️ $key가 Map임: $value - 첫 번째 문자열 값 찾는 중...');
        for (var mapValue in value.values) {
          if (mapValue is String && mapValue.isNotEmpty) {
            return mapValue;
          }
        }
        return null;
      }

      if (value is List) {
        print('⚠️ $key가 List임: $value - 첫 번째 문자열 값 찾는 중...');
        for (var listValue in value) {
          if (listValue is String && listValue.isNotEmpty) {
            return listValue;
          }
        }
        return null;
      }

      return value.toString();
    } catch (e) {
      print('❌ $key String 추출 오류: $e');
      return null;
    }
  }

  double? _safeExtractDouble(Map<String, dynamic> map, String key) {
    try {
      final value = map[key];
      if (value == null) return null;

      if (value is double) {
        return value;
      }

      if (value is int) {
        return value.toDouble();
      }

      if (value is String) {
        return double.tryParse(value);
      }

      if (value is Map) {
        print('⚠️ $key가 Map임: $value - 숫자 값 찾는 중...');
        for (var mapValue in value.values) {
          if (mapValue is num) {
            return mapValue.toDouble();
          }
        }
        return null;
      }

      if (value is bool) {
        return value ? 1.0 : 0.0;
      }

      return null;
    } catch (e) {
      print('❌ $key Double 추출 오류: $e');
      return null;
    }
  }


// 안전한 타입 변환 함수들 수정
  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;

    try {
      if (value is Map<String, dynamic>) {
        // Map인 경우 첫 번째 문자열 값 반환하거나 JSON 문자열로 변환
        for (var val in value.values) {
          if (val is String && val.isNotEmpty) return val;
        }
        // 문자열 값이 없으면 빈 문자열 반환
        return '';
      }
      return value.toString();
    } catch (e) {
      print('타입 변환 오류: $e, 값: $value, 타입: ${value.runtimeType}');
      return '';
    }
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        final parsed = double.parse(value);
        return parsed.round();
      } catch (e) {
        return 0;
      }
    }
    if (value is bool) return value ? 1 : 0;
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    if (value is bool) return value ? 1.0 : 0.0;
    return 0.0;
  }


// 완전히 안전한 값 정리 (재귀적 처리)
  dynamic _sanitizeValueCompletely(dynamic value) {
    try {
      if (value == null) {
        return null;
      } else if (value is String || value is bool || value is num) {
        return value;
      } else if (value is List) {
        return value.where((item) => item != null).map((item) => _sanitizeValueCompletely(item)).toList();
      } else if (value is Map) {
        final sanitizedMap = <String, dynamic>{};
        for (final entry in value.entries) {
          final mapKey = entry.key;
          final mapValue = entry.value;
          if (mapValue != null) {
            sanitizedMap[mapKey.toString()] = _sanitizeValueCompletely(mapValue);
          }
        }
        return sanitizedMap;
      } else {
        return value.toString();
      }
    } catch (e) {
      print('값 정리 오류: $e, 값: $value, 타입: ${value.runtimeType}');
      return value?.toString() ?? '';
    }
  }


  bool _safeBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is double) return value != 0.0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

// 3. 완전히 안전한 사용자 컨텍스트 정리 (타입 캐스팅 완전 제거)
  Map<String, dynamic> _sanitizeUserContextCompletely(Map<String, dynamic> userContext) {
    final sanitized = <String, dynamic>{};

    try {
      for (final entry in userContext.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value != null) {
          sanitized[key] = _sanitizeValueCompletely(value);
        }
      }
    } catch (e) {
      print('사용자 컨텍스트 정리 오류: $e');
    }

    return sanitized;
  }

// 5. 안전한 의미적 키워드 추출 (완전히 수정된 버전)
  List<String> _extractSemanticKeywordsSafe(String? title, String? description) {
    try {
      final text = '${_safeString(title)} ${_safeString(description)}'.toLowerCase().trim();
      if (text.isEmpty) return ['general'];

      final keywords = <String>[];

      final keywordGroups = <String, List<String>>{
        'travel': ['여행', 'travel', '항공', 'flight', '호텔', 'hotel', '출국', '비행기', '공항', '숙박'],
        'work': ['회의', 'meeting', '업무', 'work', '프로젝트', 'project', '발표', 'presentation', '보고서'],
        'health': ['운동', 'exercise', '헬스', 'gym', '조깅', 'running', '요가', 'yoga', '병원', '건강'],
        'study': ['공부', 'study', '학습', '수업', 'class', '강의', '시험', 'exam', '과제', '독서'],
        'social': ['약속', '만남', 'appointment', '친구', 'friend', '가족', 'family', '데이트', '모임'],
        'household': ['청소', 'cleaning', '요리', 'cooking', '쇼핑', 'shopping', '세탁', '정리'],
        'finance': ['은행', 'bank', '결제', '세금', 'tax', '투자', '보험', '대출'],
        'maintenance': ['수리', '점검', '교체', '설치', '관리', 'maintenance', '서비스'],
      };

      for (final entry in keywordGroups.entries) {
        for (final keyword in entry.value) {
          if (text.contains(keyword)) {
            keywords.add(entry.key);
            break;
          }
        }
      }

      return keywords.isEmpty ? ['general'] : keywords;
    } catch (e) {
      print('의미적 키워드 추출 오류: $e');
      return ['general'];
    }
  }

// 6. 완전히 안전한 태스크 관계 분석
  Map<String, dynamic> _analyzeTaskRelationsSafe(Todo_Task task, List<Todo_Task> allTasks) {
    try {
      final relations = <String, dynamic>{
        'prerequisites': <String>[],
        'dependents': <String>[],
        'parallelTasks': <String>[],
        'conflictingTasks': <String>[],
        'synergisticTasks': <String>[],
      };

      final taskTitle = _safeString(task.title);
      if (taskTitle.isEmpty) return relations;

      final taskCategory = _getTaskType(taskTitle);
      final taskKeywords = _extractSemanticKeywordsSafe(task.title, task.description);

      for (var otherTask in allTasks) {
        if (_safeString(otherTask.id) == _safeString(task.id)) continue;

        final otherTitle = _safeString(otherTask.title);
        if (otherTitle.isEmpty) continue;

        final otherCategory = _getTaskType(otherTitle);
        final otherKeywords = _extractSemanticKeywordsSafe(otherTask.title, otherTask.description);

        // 같은 카테고리의 유사한 태스크들
        if (taskCategory == otherCategory) {
          (relations['parallelTasks'] as List<String>).add(otherTitle);
        }

        // 키워드 기반 시너지 태스크
        final commonKeywords = taskKeywords.toSet().intersection(otherKeywords.toSet());
        if (commonKeywords.isNotEmpty) {
          (relations['synergisticTasks'] as List<String>).add(otherTitle);
        }

        // 시간 충돌 태스크
        final taskTime = _safeString(task.time);
        final otherTime = _safeString(otherTask.time);
        if (taskTime.isNotEmpty && otherTime.isNotEmpty) {
          try {
            final taskHour = _parseTimeToHour(taskTime);
            final otherHour = _parseTimeToHour(otherTime);
            if ((taskHour - otherHour).abs() <= 1) {
              (relations['conflictingTasks'] as List<String>).add(otherTitle);
            }
          } catch (e) {
            // 시간 파싱 실패 시 무시
          }
        }
      }

      return relations;
    } catch (e) {
      print('태스크 관계 분석 오류: $e');
      return <String, dynamic>{
        'prerequisites': <String>[],
        'dependents': <String>[],
        'parallelTasks': <String>[],
        'conflictingTasks': <String>[],
        'synergisticTasks': <String>[],
      };
    }
  }

// 7. 완전히 안전한 유사 태스크 히스토리 분석
  Map<String, dynamic> _findSimilarTasksInHistorySafe(Todo_Task task) {
    try {
      final now = DateTime.now();
      final similarTasks = <Map<String, dynamic>>[];
      final taskTitle = _safeString(task.title);

      if (taskTitle.isEmpty) {
        return <String, dynamic>{
          'count': 0,
          'averageSimilarity': 0.0,
          'averageCompletionRate': 0.0,
          'topMatches': <Map<String, dynamic>>[],
        };
      }

      // 최근 30일간의 태스크 검색
      for (int i = 1; i <= 30; i++) {
        try {
          final pastDate = now.subtract(Duration(days: i));
          final pastTasks = _taskDataService.getTodoTasksForDate(pastDate);

          for (var pastTask in pastTasks) {
            final pastTitle = _safeString(pastTask.title);
            if (pastTitle.isEmpty) continue;

            final similarity = _calculateTaskSimilaritySafe(task, pastTask);
            if (similarity > 0.6) {
              similarTasks.add(<String, dynamic>{
                'title': pastTitle,
                'similarity': _safeDouble(similarity),
                'completed': _safeBool(pastTask.isCompleted),
                'daysAgo': i,
                'time': _safeString(pastTask.time),
                'category': _safeString(_getTaskType(pastTitle)),
              });
            }
          }
        } catch (e) {
          // 개별 날짜 처리 실패 시 계속 진행
          continue;
        }
      }

      // 가장 유사한 상위 5개만 반환
      similarTasks.sort((a, b) => _safeDouble(b['similarity']).compareTo(_safeDouble(a['similarity'])));

      final completedCount = similarTasks.where((t) => _safeBool(t['completed'])).length;

      return <String, dynamic>{
        'count': similarTasks.length,
        'averageSimilarity': similarTasks.isNotEmpty
            ? similarTasks.map((t) => _safeDouble(t['similarity'])).reduce((a, b) => a + b) / similarTasks.length
            : 0.0,
        'averageCompletionRate': similarTasks.isNotEmpty
            ? completedCount / similarTasks.length
            : 0.0,
        'topMatches': similarTasks.take(5).toList(),
      };
    } catch (e) {
      print('유사 태스크 히스토리 분석 오류: $e');
      return <String, dynamic>{
        'count': 0,
        'averageSimilarity': 0.0,
        'averageCompletionRate': 0.0,
        'topMatches': <Map<String, dynamic>>[],
      };
    }
  }

// 8. 완전히 안전한 태스크 유사도 계산
  double _calculateTaskSimilaritySafe(Todo_Task task1, Todo_Task task2) {
    try {
      final title1 = _safeString(task1.title).toLowerCase().trim();
      final title2 = _safeString(task2.title).toLowerCase().trim();

      if (title1.isEmpty || title2.isEmpty) return 0.0;

      double similarity = 0.0;

      // 제목 유사도 (단어 기반)
      final title1Words = title1.split(' ').where((w) => w.isNotEmpty).toSet();
      final title2Words = title2.split(' ').where((w) => w.isNotEmpty).toSet();

      if (title1Words.isNotEmpty && title2Words.isNotEmpty) {
        final commonWords = title1Words.intersection(title2Words);
        final titleSimilarity = commonWords.isNotEmpty
            ? (2.0 * commonWords.length) / (title1Words.length + title2Words.length)
            : 0.0;
        similarity += titleSimilarity * 0.4;
      }

      // 카테고리 유사도
      if (_getTaskType(title1) == _getTaskType(title2)) {
        similarity += 0.3;
      }

      // 중요도/긴급도 유사도
      final importance1 = _safeInt(task1.importance);
      final importance2 = _safeInt(task2.importance);
      final urgency1 = _safeInt(task1.urgency);
      final urgency2 = _safeInt(task2.urgency);

      final importanceDiff = (importance1 - importance2).abs();
      final urgencyDiff = (urgency1 - urgency2).abs();
      similarity += (1.0 - (importanceDiff + urgencyDiff) / 10.0) * 0.2;

      // 시간대 유사도
      final time1 = _safeString(task1.time);
      final time2 = _safeString(task2.time);
      if (time1.isNotEmpty && time2.isNotEmpty) {
        try {
          final hour1 = _parseTimeToHour(time1);
          final hour2 = _parseTimeToHour(time2);
          final hourDiff = (hour1 - hour2).abs();
          similarity += (1.0 - hourDiff / 24.0) * 0.1;
        } catch (e) {
          // 시간 파싱 실패 시 무시
        }
      }

      return similarity.clamp(0.0, 1.0);
    } catch (e) {
      print('태스크 유사도 계산 오류: $e');
      return 0.0;
    }
  }


  // 사용자 완료 패턴을 심층 분석하는 함수
  Future<Map<String, dynamic>> _analyzeUserCompletionPatterns() async {
    try {
      print('📊 사용자 완료 패턴 심층 분석 시작');

      final now = DateTime.now();
      final patterns = <String, dynamic>{
        'dailyCompletionRates': <String, double>{},
        'categorySuccessRates': <String, double>{},
        'timeSlotEffectiveness': <int, double>{},
        'weeklyTrends': <String, double>{},
        'seasonalPatterns': <String, double>{},
        'taskComplexityHandling': <String, double>{},
        'consistencyScore': 0.0,
        'improvementTrend': 0.0,
        'peakPerformanceHours': <int>[],
        'lowPerformanceHours': <int>[],
        'contextualFactors': <String, dynamic>{},
      };

      // 최근 90일간의 상세 데이터 분석
      final completionData = <Map<String, dynamic>>[];

      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dayTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        final allTasks = [...dayTasks, ...plannerTasks];

        if (allTasks.isNotEmpty) {
          final completed = allTasks.where((task) => task.isCompleted).length;
          final total = allTasks.length;
          final completionRate = completed / total;

          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          patterns['dailyCompletionRates'][dateKey] = completionRate;

          // 요일별 성공률 분석
          final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
          final weekdayKey = weekdayNames[date.weekday - 1];

          if (!patterns['weeklyTrends'].containsKey(weekdayKey)) {
            patterns['weeklyTrends'][weekdayKey] = <double>[];
          }
          (patterns['weeklyTrends'][weekdayKey] as List<double>).add(completionRate);

          // 카테고리별 성공률 분석
          final categoryStats = <String, Map<String, int>>{};
          for (var task in allTasks) {
            final category = _getTaskType(task.title);
            if (!categoryStats.containsKey(category)) {
              categoryStats[category] = {'total': 0, 'completed': 0};
            }
            categoryStats[category]!['total'] = categoryStats[category]!['total']! + 1;
            if (task.isCompleted) {
              categoryStats[category]!['completed'] = categoryStats[category]!['completed']! + 1;
            }
          }

          // 시간대별 효율성 분석
          final hourlyStats = <int, Map<String, int>>{};
          for (var task in allTasks) {
            if (task.time != null) {
              try {
                final hour = _parseTimeToHour(task.time!);
                if (!hourlyStats.containsKey(hour)) {
                  hourlyStats[hour] = {'total': 0, 'completed': 0};
                }
                hourlyStats[hour]!['total'] = hourlyStats[hour]!['total']! + 1;
                if (task.isCompleted) {
                  hourlyStats[hour]!['completed'] = hourlyStats[hour]!['completed']! + 1;
                }
              } catch (e) {
                // 시간 파싱 실패 시 무시
              }
            }
          }

          // 복잡도별 성공률 분석
          final complexityStats = <String, Map<String, int>>{
            'low': {'total': 0, 'completed': 0},
            'medium': {'total': 0, 'completed': 0},
            'high': {'total': 0, 'completed': 0},
          };

          for (var task in allTasks) {
            final complexity = _calculateTaskComplexity(task);
            String level;
            if (complexity <= 0.3) level = 'low';
            else if (complexity <= 0.7) level = 'medium';
            else level = 'high';

            complexityStats[level]!['total'] = complexityStats[level]!['total']! + 1;
            if (task.isCompleted) {
              complexityStats[level]!['completed'] = complexityStats[level]!['completed']! + 1;
            }
          }

          completionData.add({
            'date': dateKey,
            'completionRate': completionRate,
            'categoryStats': categoryStats,
            'hourlyStats': hourlyStats,
            'complexityStats': complexityStats,
            'totalTasks': total,
            'weekday': date.weekday,
            'isWeekend': date.weekday >= 6,
            'month': date.month,
            'season': _getSeason(date),
          });
        }
      }

      // 요일별 평균 계산
      patterns['weeklyTrends'].forEach((weekday, rates) {
        if (rates is List<double> && rates.isNotEmpty) {
          patterns['weeklyTrends'][weekday] = rates.reduce((a, b) => a + b) / rates.length;
        }
      });

      // 카테고리별 성공률 집계
      final globalCategoryStats = <String, Map<String, int>>{};
      for (var dayData in completionData) {
        final categoryStats = dayData['categoryStats'] as Map<String, Map<String, int>>;
        categoryStats.forEach((category, stats) {
          if (!globalCategoryStats.containsKey(category)) {
            globalCategoryStats[category] = {'total': 0, 'completed': 0};
          }
          globalCategoryStats[category]!['total'] = globalCategoryStats[category]!['total']! + stats['total']!;
          globalCategoryStats[category]!['completed'] = globalCategoryStats[category]!['completed']! + stats['completed']!;
        });
      }

      globalCategoryStats.forEach((category, stats) {
        if (stats['total']! > 0) {
          patterns['categorySuccessRates'][category] = stats['completed']! / stats['total']!;
        }
      });

      // 시간대별 효율성 집계
      final globalHourlyStats = <int, Map<String, int>>{};
      for (var dayData in completionData) {
        final hourlyStats = dayData['hourlyStats'] as Map<int, Map<String, int>>;
        hourlyStats.forEach((hour, stats) {
          if (!globalHourlyStats.containsKey(hour)) {
            globalHourlyStats[hour] = {'total': 0, 'completed': 0};
          }
          globalHourlyStats[hour]!['total'] = globalHourlyStats[hour]!['total']! + stats['total']!;
          globalHourlyStats[hour]!['completed'] = globalHourlyStats[hour]!['completed']! + stats['completed']!;
        });
      }

      globalHourlyStats.forEach((hour, stats) {
        if (stats['total']! > 0) {
          patterns['timeSlotEffectiveness'][hour] = stats['completed']! / stats['total']!;
        }
      });

      // 복잡도별 성공률 집계
      final globalComplexityStats = <String, Map<String, int>>{
        'low': {'total': 0, 'completed': 0},
        'medium': {'total': 0, 'completed': 0},
        'high': {'total': 0, 'completed': 0},
      };

      for (var dayData in completionData) {
        final complexityStats = dayData['complexityStats'] as Map<String, Map<String, int>>;
        complexityStats.forEach((level, stats) {
          globalComplexityStats[level]!['total'] = globalComplexityStats[level]!['total']! + stats['total']!;
          globalComplexityStats[level]!['completed'] = globalComplexityStats[level]!['completed']! + stats['completed']!;
        });
      }

      globalComplexityStats.forEach((level, stats) {
        if (stats['total']! > 0) {
          patterns['taskComplexityHandling'][level] = stats['completed']! / stats['total']!;
        }
      });

      // 최고/최저 성능 시간대 식별
      final hourEffectiveness = patterns['timeSlotEffectiveness'] as Map<int, double>;
      if (hourEffectiveness.isNotEmpty) {
        final sortedHours = hourEffectiveness.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        patterns['peakPerformanceHours'] = sortedHours
            .where((e) => e.value >= 0.8)
            .map((e) => e.key)
            .take(3)
            .toList();

        patterns['lowPerformanceHours'] = sortedHours
            .where((e) => e.value <= 0.4)
            .map((e) => e.key)
            .take(3)
            .toList();
      }

      // 일관성 점수 계산
      final completionRates = (patterns['dailyCompletionRates'] as Map<String, double>).values.toList();
      if (completionRates.isNotEmpty) {
        final mean = completionRates.reduce((a, b) => a + b) / completionRates.length;
        final variance = completionRates.map((rate) => pow(rate - mean, 2)).reduce((a, b) => a + b) / completionRates.length;
        patterns['consistencyScore'] = 1.0 - sqrt(variance); // 일관성 점수 (0~1)
      }

      // 개선 트렌드 계산 (최근 30일 vs 이전 30일)
      final recentRates = completionRates.take(30).toList();
      final previousRates = completionRates.skip(30).take(30).toList();

      if (recentRates.isNotEmpty && previousRates.isNotEmpty) {
        final recentAvg = recentRates.reduce((a, b) => a + b) / recentRates.length;
        final previousAvg = previousRates.reduce((a, b) => a + b) / previousRates.length;
        patterns['improvementTrend'] = recentAvg - previousAvg;
      }

      // 계절별 패턴 분석
      final seasonalStats = <String, List<double>>{
        'spring': [],
        'summer': [],
        'autumn': [],
        'winter': [],
      };

      for (var dayData in completionData) {
        final season = dayData['season'] as String;
        final rate = dayData['completionRate'] as double;
        seasonalStats[season]!.add(rate);
      }

      seasonalStats.forEach((season, rates) {
        if (rates.isNotEmpty) {
          patterns['seasonalPatterns'][season] = rates.reduce((a, b) => a + b) / rates.length;
        }
      });

      print('📊 완료 패턴 심층 분석 완료: ${completionData.length}일 데이터');
      print('📈 카테고리별 성공률: ${patterns['categorySuccessRates']}');
      print('⏰ 최고 성능 시간대: ${patterns['peakPerformanceHours']}');
      print('📊 일관성 점수: ${patterns['consistencyScore']}');

      return patterns;

    } catch (e) {
      print('완료 패턴 분석 오류: $e');
      return {
        'dailyCompletionRates': <String, double>{},
        'categorySuccessRates': <String, double>{},
        'timeSlotEffectiveness': <int, double>{},
        'weeklyTrends': <String, double>{},
        'consistencyScore': 0.5,
        'improvementTrend': 0.0,
      };
    }
  }

// 태스크 복잡도 계산 헬퍼 함수
  double _calculateTaskComplexity(Todo_Task task) {
    double complexity = 0.0;

    // 중요도와 긴급도 기반
    complexity += (task.importance + task.urgency) / 10.0;

    // 제목 길이 기반
    complexity += min(task.title.length / 50.0, 0.3);

    // 설명 존재 여부
    if (task.description != null && task.description!.isNotEmpty) {
      complexity += 0.2;
    }

    // 마감일 압박
    if (task.dueDate != null) {
      final daysUntilDue = task.dueDate!.difference(DateTime.now()).inDays;
      if (daysUntilDue <= 1) complexity += 0.3;
      else if (daysUntilDue <= 3) complexity += 0.2;
    }

    return complexity.clamp(0.0, 1.0);
  }

// 계절 계산 헬퍼 함수
  String _getSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }
  Future<Map<String, dynamic>> _analyzeUserTimePreferences() async {
    try {
      print('⏰ 사용자 시간 선호도 동적 분석 시작');

      final preferences = <String, dynamic>{
        'preferredStartTimes': <int, int>{},
        'productiveHours': <int>[],
        'avoidHours': <int>[],
        'categoryTimePreferences': <String, List<int>>{},
        'durationPreferences': <String, Map<String, double>>{},
        'breakPatterns': <String, dynamic>{},
        'energyLevelCurve': <int, double>{}, // 시간대별 에너지 레벨
        'focusTimeSlots': <int>[],
        'socialTimeSlots': <int>[],
        'creativityPeaks': <int>[],
        'routineTimeSlots': <int>[],
        'flexibilityIndex': <int, double>{}, // 시간대별 유연성 지수
        'workflowOptimalTimes': <String, List<int>>{}, // 워크플로우별 최적 시간
        'concentrationSpans': <int, int>{}, // 집중 지속 시간 (시간대별)
        'transitionPreferences': <String, List<int>>{}, // 작업 전환 선호 시간
      };

      final now = DateTime.now();
      final hourlyPerformance = <int, List<double>>{};
      final categoryHourly = <String, Map<int, List<double>>>{};
      final hourlyTaskCounts = <int, int>{};
      final hourlyCompletionTimes = <int, List<double>>{};
      final hourlyComplexityScores = <int, List<double>>{};
      final consecutiveWorkSessions = <int, List<int>>{}; // 연속 작업 세션 분석

      // 최근 90일간의 상세 시간 분석
      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dayTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        final allTasks = [...dayTasks, ...plannerTasks];

        // 하루의 작업 시간들을 정렬
        final dailyWorkHours = <int>[];

        for (var task in allTasks) {
          if (task.time != null && task.time!.isNotEmpty) {
            try {
              final hour = _parseTimeToHour(task.time!);
              final category = _getTaskType(task.title);
              final success = task.isCompleted ? 1.0 : 0.0;
              final complexity = _calculateTaskComplexity(task);

              dailyWorkHours.add(hour);

              // 전체 시간대별 성과 기록
              if (!hourlyPerformance.containsKey(hour)) {
                hourlyPerformance[hour] = <double>[];
              }
              hourlyPerformance[hour]!.add(success);

              // 시간대별 태스크 수 집계
              hourlyTaskCounts[hour] = (hourlyTaskCounts[hour] ?? 0) + 1;

              // 복잡도별 시간대 분석
              if (!hourlyComplexityScores.containsKey(hour)) {
                hourlyComplexityScores[hour] = <double>[];
              }
              hourlyComplexityScores[hour]!.add(complexity);

              // 카테고리별 시간대 성과
              if (!categoryHourly.containsKey(category)) {
                categoryHourly[category] = <int, List<double>>{};
              }
              if (!categoryHourly[category]!.containsKey(hour)) {
                categoryHourly[category]![hour] = <double>[];
              }
              categoryHourly[category]![hour]!.add(success);

              // 시작 시간 선호도 기록
              preferences['preferredStartTimes'][hour] =
                  (preferences['preferredStartTimes'][hour] ?? 0) + 1;

              // 완료 시간 분석 (실제 걸린 시간 추정)
              if (task.endTime != null) {
                try {
                  final endHour = _parseTimeToHour(task.endTime!);
                  final duration = (endHour - hour).abs().toDouble();
                  if (!hourlyCompletionTimes.containsKey(hour)) {
                    hourlyCompletionTimes[hour] = <double>[];
                  }
                  hourlyCompletionTimes[hour]!.add(duration);
                } catch (e) {
                  // 종료 시간 파싱 실패 시 무시
                }
              }

            } catch (e) {
              print('시간 파싱 오류: $e');
            }
          }
        }

        // 연속 작업 세션 분석
        if (dailyWorkHours.isNotEmpty) {
          dailyWorkHours.sort();
          final sessions = _analyzeWorkSessions(dailyWorkHours);
          for (var session in sessions) {
            final startHour = session['start'] as int;
            final duration = session['duration'] as int;
            if (!consecutiveWorkSessions.containsKey(startHour)) {
              consecutiveWorkSessions[startHour] = <int>[];
            }
            consecutiveWorkSessions[startHour]!.add(duration);
          }
        }
      }

      // 생산적인 시간대 계산 (성공률 75% 이상, 최소 5회 이상 수행)
      final productiveHours = <int>[];
      final avoidHours = <int>[];
      final focusHours = <int>[];
      final socialHours = <int>[];
      final creativityHours = <int>[];

      hourlyPerformance.forEach((hour, successRates) {
        if (successRates.length >= 5) {
          final avgSuccess = successRates.reduce((a, b) => a + b) / successRates.length;
          preferences['energyLevelCurve'][hour] = avgSuccess;

          if (avgSuccess >= 0.75) {
            productiveHours.add(hour);

            // 고집중 작업 시간대 식별 (태스크 수가 많고 성공률이 높은 시간)
            final taskCount = hourlyTaskCounts[hour] ?? 0;
            if (taskCount >= 10) {
              focusHours.add(hour);
            }

            // 창의성 피크 시간대 식별 (복잡한 작업의 성공률이 높은 시간)
            if (hourlyComplexityScores[hour] != null) {
              final avgComplexity = hourlyComplexityScores[hour]!.reduce((a, b) => a + b) /
                  hourlyComplexityScores[hour]!.length;
              if (avgComplexity >= 0.6 && avgSuccess >= 0.8) {
                creativityHours.add(hour);
              }
            }
          } else if (avgSuccess <= 0.4) {
            avoidHours.add(hour);
          }

          // 사회적 활동 시간대 식별 (회의, 만남 등)
          final socialCategories = ['meeting', 'social'];
          bool isSocialHour = false;
          for (var category in socialCategories) {
            if (categoryHourly[category]?[hour] != null &&
                categoryHourly[category]![hour]!.length >= 3) {
              isSocialHour = true;
              break;
            }
          }
          if (isSocialHour) {
            socialHours.add(hour);
          }
        }
      });

      preferences['productiveHours'] = productiveHours..sort();
      preferences['avoidHours'] = avoidHours..sort();
      preferences['focusTimeSlots'] = focusHours..sort();
      preferences['socialTimeSlots'] = socialHours..sort();
      preferences['creativityPeaks'] = creativityHours..sort();

      // 카테고리별 최적 시간대 분석
      categoryHourly.forEach((category, hourlyData) {
        final bestHours = <int>[];
        hourlyData.forEach((hour, successRates) {
          if (successRates.length >= 3) {
            final avgSuccess = successRates.reduce((a, b) => a + b) / successRates.length;
            if (avgSuccess >= 0.7) {
              bestHours.add(hour);
            }
          }
        });
        if (bestHours.isNotEmpty) {
          preferences['categoryTimePreferences'][category] = bestHours..sort();
        }
      });

      // 루틴 시간대 식별 (반복적으로 같은 시간에 하는 일들)
      final routineHours = <int>[];
      preferences['preferredStartTimes'].forEach((hour, count) {
        if (count >= 15) { // 15번 이상 사용한 시간대
          routineHours.add(hour);
        }
      });
      preferences['routineTimeSlots'] = routineHours..sort();

      // 시간대별 유연성 지수 계산 (성과의 일관성)
      hourlyPerformance.forEach((hour, successRates) {
        if (successRates.length >= 3) {
          final avgSuccess = successRates.reduce((a, b) => a + b) / successRates.length;
          final variance = successRates.map((rate) => pow(rate - avgSuccess, 2)).reduce((a, b) => a + b) / successRates.length;
          final consistency = 1.0 - sqrt(variance); // 변동성이 낮을수록 일관성 높음
          preferences['flexibilityIndex'][hour] = consistency.clamp(0.0, 1.0);
        }
      });

      // 소요시간 선호도 분석 (작업 길이별 최적 시간대)
      final durationPrefs = <String, Map<String, double>>{
        'short': {'bestHour': 0.0, 'successRate': 0.0, 'avgDuration': 0.0}, // 1시간 이하
        'medium': {'bestHour': 0.0, 'successRate': 0.0, 'avgDuration': 0.0}, // 1-3시간
        'long': {'bestHour': 0.0, 'successRate': 0.0, 'avgDuration': 0.0}, // 3시간 이상
      };

      hourlyCompletionTimes.forEach((hour, durations) {
        if (durations.isNotEmpty) {
          final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
          final successRate = hourlyPerformance[hour] != null
              ? hourlyPerformance[hour]!.reduce((a, b) => a + b) / hourlyPerformance[hour]!.length
              : 0.0;

          String durationCategory;
          if (avgDuration <= 1.0) durationCategory = 'short';
          else if (avgDuration <= 3.0) durationCategory = 'medium';
          else durationCategory = 'long';

          if (durationPrefs[durationCategory]!['bestHour']! == 0.0 ||
              successRate > durationPrefs[durationCategory]!['successRate']!) {
            durationPrefs[durationCategory]!['bestHour'] = hour.toDouble();
            durationPrefs[durationCategory]!['successRate'] = successRate;
            durationPrefs[durationCategory]!['avgDuration'] = avgDuration;
          }
        }
      });
      preferences['durationPreferences'] = durationPrefs;

      // 휴식 패턴 심층 분석
      final breakPatterns = <String, dynamic>{
        'preferredBreakTimes': <int>[],
        'optimalBreakDuration': 15, // 분
        'breakFrequency': 90, // 분 (기본값)
        'energyRecoveryTimes': <int>[],
        'naturalBreakPoints': <int>[],
      };

      // 연속 작업 세션 분석으로 휴식 패턴 도출
      final workSessionGaps = <int, List<int>>{}; // 시작 시간 : [휴식 시간들]

      consecutiveWorkSessions.forEach((startHour, durations) {
        if (durations.length >= 3) {
          final avgDuration = durations.reduce((a, b) => a + b) / durations.length;

          // 집중 지속 시간 기록
          preferences['concentrationSpans'][startHour] = avgDuration.round();

          // 자연스러운 휴식 지점 식별 (작업 세션 종료 후)
          final endHour = startHour + avgDuration.round();
          if (endHour <= 22) {
            breakPatterns['naturalBreakPoints'].add(endHour);
          }
        }
      });

      // 에너지 회복 시간대 식별 (성과가 낮았다가 높아지는 구간)
      final energyRecoveryTimes = <int>[];
      for (int hour = 7; hour <= 21; hour++) {
        final prevHourPerf = preferences['energyLevelCurve'][hour - 1] ?? 0.0;
        final currentHourPerf = preferences['energyLevelCurve'][hour] ?? 0.0;
        final nextHourPerf = preferences['energyLevelCurve'][hour + 1] ?? 0.0;

        // 이전 시간보다 현재가 높고, 다음 시간이 더 높다면 회복 시간대
        if (currentHourPerf > prevHourPerf && nextHourPerf > currentHourPerf) {
          energyRecoveryTimes.add(hour);
        }
      }
      breakPatterns['energyRecoveryTimes'] = energyRecoveryTimes..sort();

      // 선호하는 휴식 시간대 최종 계산
      final allBreakTimes = <int>{};
      allBreakTimes.addAll(breakPatterns['naturalBreakPoints']);
      allBreakTimes.addAll(energyRecoveryTimes);

      // 일반적인 휴식 시간도 포함 (점심시간, 오후 휴식 등)
      final commonBreakTimes = [12, 15, 17]; // 점심, 오후휴식, 퇴근 전
      for (var time in commonBreakTimes) {
        if (hourlyTaskCounts[time] == null || hourlyTaskCounts[time]! < 5) {
          allBreakTimes.add(time);
        }
      }

      breakPatterns['preferredBreakTimes'] = allBreakTimes.toList()..sort();
      preferences['breakPatterns'] = breakPatterns;

      // 워크플로우별 최적 시간 분석
      final workflowTimes = <String, List<int>>{
        'planning': [], // 계획 수립
        'execution': [], // 실행
        'review': [], // 검토
        'creative': [], // 창의적 작업
        'routine': [], // 루틴 작업
        'communication': [], // 소통
      };

      // 각 워크플로우 타입별 최적 시간 매핑
      productiveHours.forEach((hour) {
        if (creativityHours.contains(hour)) {
          workflowTimes['creative']!.add(hour);
          workflowTimes['planning']!.add(hour);
        }
        if (focusHours.contains(hour)) {
          workflowTimes['execution']!.add(hour);
        }
        if (socialHours.contains(hour)) {
          workflowTimes['communication']!.add(hour);
        }
        if (routineHours.contains(hour)) {
          workflowTimes['routine']!.add(hour);
        }
      });

      // 검토 시간은 보통 하루 끝에
      final reviewHours = productiveHours.where((h) => h >= 16 && h <= 19).toList();
      workflowTimes['review'] = reviewHours;

      preferences['workflowOptimalTimes'] = workflowTimes;

      // 작업 전환 선호 시간 분석
      final transitionTimes = <String, List<int>>{
        'categorySwitch': [], // 다른 카테고리로 전환
        'complexityChange': [], // 복잡도 변경
        'modeSwitch': [], // 작업 모드 전환 (집중 -> 협업 등)
      };

      // 유연성이 높고 성과도 괜찮은 시간대를 전환 시간으로 설정
      preferences['flexibilityIndex'].forEach((hour, flexibility) {
        final performance = preferences['energyLevelCurve'][hour] ?? 0.0;
        if (flexibility >= 0.7 && performance >= 0.6) {
          transitionTimes['categorySwitch']!.add(hour);
          transitionTimes['complexityChange']!.add(hour);
          transitionTimes['modeSwitch']!.add(hour);
        }
      });

      preferences['transitionPreferences'] = transitionTimes;

      print('⏰ 시간 선호도 동적 분석 완료');
      print('🚀 생산적 시간대: $productiveHours');
      print('❌ 회피 시간대: $avoidHours');
      print('🎯 집중 시간대: $focusHours');
      print('👥 사회적 시간대: $socialHours');
      print('💡 창의성 피크: $creativityHours');
      print('🔄 루틴 시간대: $routineHours');
      print('📝 카테고리별 최적 시간: ${preferences['categoryTimePreferences']}');
      print('⚡ 에너지 회복 시간: $energyRecoveryTimes');

      return preferences;

    } catch (e) {
      print('시간 선호도 분석 오류: $e');
      return {
        'preferredStartTimes': <int, int>{},
        'productiveHours': [9, 10, 14, 15],
        'avoidHours': <int>[],
        'categoryTimePreferences': <String, List<int>>{},
        'durationPreferences': <String, Map<String, double>>{},
        'breakPatterns': <String, dynamic>{
          'preferredBreakTimes': [12, 15, 17],
          'optimalBreakDuration': 15,
          'breakFrequency': 90,
        },
        'energyLevelCurve': <int, double>{},
        'focusTimeSlots': [9, 10, 14],
        'socialTimeSlots': [11, 15, 16],
        'creativityPeaks': [10, 15],
        'routineTimeSlots': [8, 12, 18],
        'flexibilityIndex': <int, double>{},
        'workflowOptimalTimes': <String, List<int>>{},
        'concentrationSpans': <int, int>{},
        'transitionPreferences': <String, List<int>>{},
      };
    }
  }

// 작업 세션 분석 헬퍼 함수
  List<Map<String, int>> _analyzeWorkSessions(List<int> workHours) {
    final sessions = <Map<String, int>>[];

    if (workHours.isEmpty) return sessions;

    int sessionStart = workHours[0];
    int sessionEnd = workHours[0];

    for (int i = 1; i < workHours.length; i++) {
      if (workHours[i] <= sessionEnd + 2) { // 2시간 이내 간격이면 같은 세션
        sessionEnd = workHours[i];
      } else {
        // 세션 종료, 새 세션 시작
        sessions.add({
          'start': sessionStart,
          'end': sessionEnd,
          'duration': sessionEnd - sessionStart + 1,
        });
        sessionStart = workHours[i];
        sessionEnd = workHours[i];
      }
    }

    // 마지막 세션 추가
    sessions.add({
      'start': sessionStart,
      'end': sessionEnd,
      'duration': sessionEnd - sessionStart + 1,
    });

    return sessions;
  }

  // AI 모델을 위한 상세한 사용자 컨텍스트 구성 함수
  Future<Map<String, dynamic>> _buildAIModelContext(
      List<Todo_Task> existingTasks,
      Map<String, dynamic> additionalData
      ) async {
    try {
      print('🧠 AI 모델용 상세 컨텍스트 구성 시작');

      // 기본 사용자 정보
      final userPreferences = await _getUserPreferences();

      final aiContext = <String, dynamic>{
        // 기본 사용자 정보
        'userId': userId,
        'currentDate': selectedDate.toIso8601String().split('T')[0],
        'currentTime': DateTime.now().toIso8601String(),
        'timezone': 'Asia/Seoul',
        'language': 'ko',
        'dayOfWeek': selectedDate.weekday,
        'isWeekend': selectedDate.weekday >= 6,
        'seasonInfo': _getCurrentSeasonInfo(),

        // 기본 설정
        'userPreferences': {
          'sleepSchedule': userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00',
          'breakFrequency': userPreferences['breakFrequency'] ?? '1시간마다',
          'preferredTimeOfDay': userPreferences['preferredTimeOfDay'] ?? ['아침'],
          'focusEnvironment': userPreferences['focusEnvironment'] ?? 'quiet',
          'workStyle': userPreferences['workStyle'] ?? 'balanced',
          'notificationPreferences': userPreferences['notificationPreferences'] ?? 'moderate',
        },

        // 현재 세션 정보
        'currentSession': {
          'totalExistingTasks': existingTasks.length,
          'completedTasks': existingTasks.where((t) => t.isCompleted).length,
          'currentProgress': existingTasks.isNotEmpty
              ? existingTasks.where((t) => t.isCompleted).length / existingTasks.length
              : 0.0,
          'currentHour': DateTime.now().hour,
          'timeUntilBedtime': _calculateTimeUntilBedtime(userPreferences['sleepSchedule']),
          'availableTimeSlots': _calculateAvailableTimeSlots(existingTasks),
          'workloadLevel': _calculateCurrentWorkloadLevel(existingTasks),
          'stressLevel': _calculateCurrentStressLevel(existingTasks),
          'energyLevel': _estimateCurrentEnergyLevel(),
        },

        // 학습 데이터
        'userLearningData': additionalData['userLearningData'] ?? {},
        'timePreferences': additionalData['timePreferences'] ?? {},
        'behaviorPatterns': additionalData['behaviorPatterns'] ?? {},
        'completionHistory': additionalData['userLearningData']?['completionHistory'] ?? {},

        // 컨텍스트 분석
        'contextAnalysis': await _analyzeCurrentContext(existingTasks),
        'taskAnalysis': _analyzeExistingTasksForAI(existingTasks),
        'temporalContext': _analyzeTemporalContext(),
        'environmentalContext': _analyzeEnvironmentalContext(),

        // AI 모델 설정
        'aiSettings': {
          'recommendationStyle': 'contextual_intelligent',
          'learningEnabled': true,
          'adaptationLevel': additionalData['userLearningData']?['adaptationLevel'] ?? 0.5,
          'personalityProfile': await _generatePersonalityProfile(),
          'cognitiveLoadThreshold': _calculateCognitiveLoadThreshold(),
          'creativityBoostNeeded': _assessCreativityBoostNeed(existingTasks),
          'socialInteractionNeeded': _assessSocialInteractionNeed(existingTasks),
        },

        // 제약 조건
        'constraints': {
          'availableTimeWindows': _getAvailableTimeWindows(existingTasks),
          'blockedTimeSlots': _getBlockedTimeSlots(existingTasks),
          'minimumBreakRequired': _calculateMinimumBreakRequired(),
          'maxDailyWorkload': _calculateMaxDailyWorkload(),
          'energyBudget': _calculateEnergyBudget(),
          'contextSwitchingLimits': _getContextSwitchingLimits(),
        },

        // 목표 및 의도
        'userGoals': {
          'shortTermGoals': await _identifyShortTermGoals(existingTasks),
          'longTermObjectives': await _identifyLongTermObjectives(),
          'priorityAreas': _identifyPriorityAreas(existingTasks),
          'improvementAreas': _identifyImprovementAreas(),
          'balanceNeeds': _assessWorkLifeBalance(existingTasks),
        },

        // 실시간 데이터
        'realtimeFactors': {
          'weatherInfo': await _getWeatherContext(),
          'calendarDensity': additionalData['calendarEvents']?.length ?? 0,
          'upcomingDeadlines': _getUpcomingDeadlines(existingTasks),
          'recentCompletionTrend': await _calculateRecentCompletionTrend(),
          'currentMoodIndicator': _estimateCurrentMood(existingTasks),
          'motivationLevel': _estimateMotivationLevel(existingTasks),
        },

        // 고급 분석 데이터
        'advancedAnalytics': {
          'taskSequencePatterns': await _analyzeTaskSequencePatterns(),
          'contextualSuccessFactors': await _analyzeContextualSuccessFactors(),
          'cognitiveLoadPatterns': await _analyzeCognitiveLoadPatterns(),
          'flowStateIndicators': await _analyzeFlowStateIndicators(),
          'procrastinationPatterns': await _analyzeProcrastinationPatterns(),
          'peakPerformanceWindows': await _identifyPeakPerformanceWindows(),
        },

        // 메타데이터
        'metadata': {
          'analysisTimestamp': DateTime.now().toIso8601String(),
          'dataQualityScore': _calculateDataQualityScore(),
          'confidenceLevel': _calculateAnalysisConfidence(),
          'recommendationScope': 'comprehensive',
          'personalizedWeight': _calculatePersonalizationWeight(),
        },
      };

      print('🧠 AI 모델 컨텍스트 구성 완료');
      print('📊 데이터 품질 점수: ${aiContext['metadata']['dataQualityScore']}');
      print('🎯 개인화 가중치: ${aiContext['metadata']['personalizedWeight']}');
      print('⚡ 현재 에너지 레벨: ${aiContext['currentSession']['energyLevel']}');
      print('🧭 작업 부하 레벨: ${aiContext['currentSession']['workloadLevel']}');

      return aiContext;

    } catch (e) {
      print('❌ AI 모델 컨텍스트 구성 오류: $e');
      // 기본 컨텍스트 반환
      return await _buildBasicAIContext(existingTasks);
    }
  }

// 현재 컨텍스트 분석
  Future<Map<String, dynamic>> _analyzeCurrentContext(List<Todo_Task> tasks) async {
    final analysis = <String, dynamic>{
      'dominantThemes': <String>[],
      'contextualCohesion': 0.0,
      'taskInterconnectedness': 0.0,
      'thematicClusters': <String, List<String>>{},
      'contextualGaps': <String>[],
      'synergisticOpportunities': <String>[],
    };

    try {
      // 테마 분석
      final themes = <String, int>{};
      final categories = <String, List<Todo_Task>>{};

      for (var task in tasks) {
        final category = _getTaskType(task.title);
        themes[category] = (themes[category] ?? 0) + 1;

        if (!categories.containsKey(category)) {
          categories[category] = <Todo_Task>[];
        }
        categories[category]!.add(task);
      }

      // 지배적 테마 식별
      final sortedThemes = themes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      analysis['dominantThemes'] = sortedThemes.take(3).map((e) => e.key).toList();

      // 테마별 클러스터링
      final clusters = <String, List<String>>{};
      categories.forEach((category, categoryTasks) {
        if (categoryTasks.length >= 2) {
          clusters[category] = categoryTasks.map((t) => t.title).toList();
        }
      });
      analysis['thematicClusters'] = clusters;

      // 컨텍스트 응집도 계산
      if (tasks.isNotEmpty) {
        final maxThemeCount = themes.values.isNotEmpty ? themes.values.reduce((a, b) => a > b ? a : b) : 0;
        analysis['contextualCohesion'] = maxThemeCount / tasks.length;
      }

      // 태스크 상호연관성 분석
      double interconnectedness = 0.0;
      int connectionCount = 0;

      for (int i = 0; i < tasks.length; i++) {
        for (int j = i + 1; j < tasks.length; j++) {
          final similarity = _calculateTaskSimilarity(tasks[i], tasks[j]);
          if (similarity > 0.5) {
            interconnectedness += similarity;
            connectionCount++;
          }
        }
      }

      if (connectionCount > 0) {
        analysis['taskInterconnectedness'] = interconnectedness / connectionCount;
      }

      // 컨텍스트 갭 식별 (빠진 중요한 영역들)
      final expectedCategories = ['work', 'health', 'personal', 'social', 'learning'];
      final presentCategories = themes.keys.toSet();
      final gaps = expectedCategories.where((cat) => !presentCategories.contains(cat)).toList();
      analysis['contextualGaps'] = gaps;

      // 시너지 기회 식별
      final opportunities = <String>[];
      clusters.forEach((category, taskTitles) {
        if (taskTitles.length >= 3) {
          opportunities.add('$category 배치 최적화 기회');
        }
      });

      // 시간대 기반 시너지
      final timeSlots = <int, List<Todo_Task>>{};
      for (var task in tasks) {
        if (task.time != null) {
          try {
            final hour = _parseTimeToHour(task.time!);
            if (!timeSlots.containsKey(hour)) {
              timeSlots[hour] = <Todo_Task>[];
            }
            timeSlots[hour]!.add(task);
          } catch (e) {}
        }
      }

      timeSlots.forEach((hour, hourTasks) {
        if (hourTasks.length >= 2) {
          final categories = hourTasks.map((t) => _getTaskType(t.title)).toSet();
          if (categories.length == 1) {
            opportunities.add('${hour}시대 ${categories.first} 집중 시간 활용');
          }
        }
      });

      analysis['synergisticOpportunities'] = opportunities;

    } catch (e) {
      print('컨텍스트 분석 오류: $e');
    }

    return analysis;
  }

// 현재 계절 정보
  Map<String, dynamic> _getCurrentSeasonInfo() {
    final now = DateTime.now();
    final month = now.month;

    String season;
    if (month >= 3 && month <= 5) season = 'spring';
    else if (month >= 6 && month <= 8) season = 'summer';
    else if (month >= 9 && month <= 11) season = 'autumn';
    else season = 'winter';

    return {
      'season': season,
      'month': month,
      'dayLength': _calculateDayLength(now),
      'seasonalMood': _getSeasonalMoodFactor(season),
    };
  }

// 잠자리 시간까지 계산
  int _calculateTimeUntilBedtime(String? sleepSchedule) {
    try {
      if (sleepSchedule == null) return 8;

      final parts = sleepSchedule.split('~');
      if (parts.length != 2) return 8;

      final bedtimePart = parts[0].trim();
      final timePart = bedtimePart.replaceAll('PM', '').replaceAll('AM', '').trim();
      final hour = int.parse(timePart.split(':')[0]);
      final adjustedHour = bedtimePart.contains('PM') ? hour + 12 : hour;

      final now = DateTime.now();
      final bedtime = DateTime(now.year, now.month, now.day, adjustedHour);

      if (bedtime.isBefore(now)) {
        return bedtime.add(Duration(days: 1)).difference(now).inHours;
      } else {
        return bedtime.difference(now).inHours;
      }
    } catch (e) {
      return 8; // 기본값
    }
  }

// 사용 가능한 시간 슬롯 계산
  List<String> _calculateAvailableTimeSlots(List<Todo_Task> tasks) {
    final occupiedHours = <int>{};

    for (var task in tasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          occupiedHours.add(hour);

          // 종료 시간이 있으면 그 사이 시간도 점유
          if (task.endTime != null) {
            final endHour = _parseTimeToHour(task.endTime!);
            for (int h = hour; h <= endHour; h++) {
              occupiedHours.add(h);
            }
          }
        } catch (e) {}
      }
    }

    final availableSlots = <String>[];
    for (int hour = 6; hour <= 23; hour++) {
      if (!occupiedHours.contains(hour)) {
        availableSlots.add('${hour.toString().padLeft(2, '0')}:00');
      }
    }

    return availableSlots;
  }

// 현재 작업 부하 레벨 계산
  String _calculateCurrentWorkloadLevel(List<Todo_Task> tasks) {
    if (tasks.isEmpty) return 'low';

    final totalTasks = tasks.length;
    final highPriorityTasks = tasks.where((t) => t.importance >= 4 || t.urgency >= 4).length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;

    final workloadScore = totalTasks * 0.4 + highPriorityTasks * 0.4 + (totalTasks - completedTasks) * 0.2;

    if (workloadScore >= 8) return 'very_high';
    if (workloadScore >= 6) return 'high';
    if (workloadScore >= 4) return 'medium';
    if (workloadScore >= 2) return 'low';
    return 'very_low';
  }

  int _calculateCurrentStressLevel([List<Todo_Task>? tasks]) {
    try {
      final targetTasks = tasks ?? _taskDataService.getTodoTasksForDate(DateTime.now());
      final urgentTasks = targetTasks.where((task) =>
      task.urgency >= 4 || task.importance >= 4).length;
      final totalTasks = targetTasks.length;

      if (totalTasks == 0) return 2;

      final stressRatio = urgentTasks / totalTasks;
      if (stressRatio >= 0.7) return 5;
      if (stressRatio >= 0.5) return 4;
      if (stressRatio >= 0.3) return 3;
      if (stressRatio >= 0.1) return 2;
      return 1;
    } catch (e) {
      return 3; // 기본값
    }
  }

// 현재 에너지 레벨 추정
  double _estimateCurrentEnergyLevel() {
    final hour = DateTime.now().hour;

    // 일반적인 에너지 곡선 (생체리듬 기반)
    if (hour >= 6 && hour <= 9) return 0.8; // 아침 에너지
    if (hour >= 10 && hour <= 11) return 0.9; // 아침 피크
    if (hour >= 12 && hour <= 13) return 0.6; // 점심 시간
    if (hour >= 14 && hour <= 16) return 0.8; // 오후 에너지
    if (hour >= 17 && hour <= 19) return 0.7; // 저녁 전
    if (hour >= 20 && hour <= 22) return 0.5; // 저녁
    return 0.3; // 늦은 시간
  }

// 기존 태스크 AI 분석
  Map<String, dynamic> _analyzeExistingTasksForAI(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'totalTasks': tasks.length,
      'categoryDistribution': <String, int>{},
      'complexityDistribution': <String, int>{'low': 0, 'medium': 0, 'high': 0},
      'priorityDistribution': <String, int>{'low': 0, 'medium': 0, 'high': 0},
      'timeDistribution': <int, int>{},
      'estimatedTotalDuration': 0.0,
      'cognitiveLoadScore': 0.0,
      'diversityScore': 0.0,
      'balanceScore': 0.0,
    };

    if (tasks.isEmpty) return analysis;

    double totalComplexity = 0.0;
    double totalDuration = 0.0;
    final categories = <String>{};

    for (var task in tasks) {
      // 카테고리 분포
      final category = _getTaskType(task.title);
      analysis['categoryDistribution'][category] = (analysis['categoryDistribution'][category] ?? 0) + 1;
      categories.add(category);

      // 복잡도 분포
      final complexity = _calculateTaskComplexity(task);
      totalComplexity += complexity;
      String complexityLevel;
      if (complexity <= 0.3) complexityLevel = 'low';
      else if (complexity <= 0.7) complexityLevel = 'medium';
      else complexityLevel = 'high';
      analysis['complexityDistribution'][complexityLevel]++;

      // 우선순위 분포
      final priority = (task.importance + task.urgency) / 2;
      String priorityLevel;
      if (priority <= 2.5) priorityLevel = 'low';
      else if (priority <= 3.5) priorityLevel = 'medium';
      else priorityLevel = 'high';
      analysis['priorityDistribution'][priorityLevel]++;

      // 시간 분포
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          analysis['timeDistribution'][hour] = (analysis['timeDistribution'][hour] ?? 0) + 1;
        } catch (e) {}
      }

      // 예상 소요시간
      final duration = _calculateTaskDuration(task);
      totalDuration += duration;
    }

    analysis['estimatedTotalDuration'] = totalDuration;
    analysis['cognitiveLoadScore'] = totalComplexity / tasks.length;
    analysis['diversityScore'] = categories.length / 7.0; // 전체 카테고리 대비

    // 밸런스 점수 (카테고리 간 균형)
    final categoryValues = (analysis['categoryDistribution'] as Map<String, int>).values.toList();
    if (categoryValues.isNotEmpty) {
      final maxCount = categoryValues.reduce((a, b) => a > b ? a : b);
      final minCount = categoryValues.reduce((a, b) => a < b ? a : b);
      analysis['balanceScore'] = minCount / maxCount;
    }

    return analysis;
  }

// 시간적 컨텍스트 분석
  Map<String, dynamic> _analyzeTemporalContext() {
    final now = DateTime.now();

    return {
      'timeOfDay': _getTimeOfDayCategory(now.hour),
      'weekPosition': _getWeekPosition(now.weekday),
      'monthPosition': _getMonthPosition(now.day),
      'yearPosition': _getYearPosition(now.month),
      'biorhythmPhase': _getBiorhythmPhase(now.hour),
      'socialRhythm': _getSocialRhythm(now.hour, now.weekday),
    };
  }

// 환경적 컨텍스트 분석
  Map<String, dynamic> _analyzeEnvironmentalContext() {
    return {
      'location': 'home', // 실제로는 위치 정보 사용
      'weatherSuitability': 'indoor', // 실제로는 날씨 API 사용
      'noiseLevel': 'quiet', // 실제로는 환경 센서 사용
      'lightingCondition': 'natural', // 시간대 기반 추정
      'distractionLevel': 'low', // 사용자 설정 기반
    };
  }

// 성격 프로필 생성
  Future<Map<String, dynamic>> _generatePersonalityProfile() async {
    // 실제로는 사용자 행동 패턴 분석으로 생성
    return {
      'workStyle': 'methodical', // systematic, creative, flexible, methodical
      'planningPreference': 'detailed', // minimal, moderate, detailed
      'riskTolerance': 'moderate', // low, moderate, high
      'socialPreference': 'balanced', // introverted, balanced, extroverted
      'focusStyle': 'deep', // quick, balanced, deep
      'adaptability': 'high', // low, moderate, high
      'motivationStyle': 'achievement', // achievement, affiliation, power
    };
  }

// 인지 부하 임계점 계산
  double _calculateCognitiveLoadThreshold() {
    // 사용자의 최대 처리 가능한 인지 부하 계산
    return 0.75; // 기본값, 실제로는 사용자 패턴 분석으로 결정
  }

// 창의성 부스트 필요성 평가
  bool _assessCreativityBoostNeed(List<Todo_Task> tasks) {
    final creativeCategories = ['design', 'planning', 'creative', 'study'];
    final creativeTasks = tasks.where((t) =>
        creativeCategories.contains(_getTaskType(t.title))
    ).length;

    return creativeTasks >= 2; // 창의적 작업이 2개 이상이면 부스트 필요
  }

// 사회적 상호작용 필요성 평가
  bool _assessSocialInteractionNeed(List<Todo_Task> tasks) {
    final individualWork = tasks.where((t) =>
    !t.title.toLowerCase().contains('회의') &&
        !t.title.toLowerCase().contains('meeting') &&
        !t.title.toLowerCase().contains('만남')
    ).length;

    return individualWork >= 5; // 개인 작업이 많으면 사회적 상호작용 필요
  }

// 사용 가능한 시간 창 계산
  List<Map<String, dynamic>> _getAvailableTimeWindows(List<Todo_Task> tasks) {
    final windows = <Map<String, dynamic>>[];
    final occupiedSlots = <int>{};

    for (var task in tasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          occupiedSlots.add(hour);
        } catch (e) {}
      }
    }

    int windowStart = -1;
    for (int hour = 6; hour <= 23; hour++) {
      if (!occupiedSlots.contains(hour)) {
        if (windowStart == -1) windowStart = hour;
      } else {
        if (windowStart != -1) {
          windows.add({
            'start': windowStart,
            'end': hour - 1,
            'duration': hour - windowStart,
          });
          windowStart = -1;
        }
      }
    }

    // 마지막 윈도우 처리
    if (windowStart != -1) {
      windows.add({
        'start': windowStart,
        'end': 23,
        'duration': 24 - windowStart,
      });
    }

    return windows;
  }

// 블록된 시간 슬롯 계산
  List<String> _getBlockedTimeSlots(List<Todo_Task> tasks) {
    final blocked = <String>[];

    for (var task in tasks) {
      if (task.time != null) {
        blocked.add(task.time!);
      }
    }

    return blocked;
  }

// 최소 휴식 시간 계산
  int _calculateMinimumBreakRequired() {
    final hour = DateTime.now().hour;

    // 시간대별 최소 휴식 필요량
    if (hour >= 6 && hour <= 9) return 5; // 아침
    if (hour >= 10 && hour <= 12) return 10; // 오전
    if (hour >= 13 && hour <= 15) return 15; // 오후 초
    if (hour >= 16 && hour <= 18) return 10; // 오후 말
    return 20; // 저녁
  }

// 최대 일일 작업량 계산
  int _calculateMaxDailyWorkload() {
    return 10; // 기본값, 실제로는 사용자 패턴 분석으로 결정
  }

// 에너지 예산 계산
  double _calculateEnergyBudget() {
    final hour = DateTime.now().hour;
    final baseEnergy = _estimateCurrentEnergyLevel();
    final hoursLeft = 22 - hour; // 10시까지

    return baseEnergy * hoursLeft * 0.8; // 80% 효율성 가정
  }

// 컨텍스트 전환 제한
  Map<String, int> _getContextSwitchingLimits() {
    return {
      'maxCategorySwitches': 4,
      'maxComplexitySwitches': 3,
      'maxLocationSwitches': 2,
      'maxModeSwitches': 5, // 집중/협업 모드 전환
    };
  }

// 기본 AI 컨텍스트 (오류 시 폴백)
  Future<Map<String, dynamic>> _buildBasicAIContext(List<Todo_Task> tasks) async {
    final userPreferences = await _getUserPreferences();

    return {
      'userId': userId,
      'currentDate': selectedDate.toIso8601String().split('T')[0],
      'currentTime': DateTime.now().toIso8601String(),
      'timezone': 'Asia/Seoul',
      'language': 'ko',
      'dayOfWeek': selectedDate.weekday,
      'isWeekend': selectedDate.weekday >= 6,

      'userPreferences': {
        'sleepSchedule': userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00',
        'breakFrequency': userPreferences['breakFrequency'] ?? '1시간마다',
        'preferredTimeOfDay': userPreferences['preferredTimeOfDay'] ?? ['아침'],
      },

      'currentSession': {
        'totalExistingTasks': tasks.length,
        'completedTasks': tasks.where((t) => t.isCompleted).length,
        'currentHour': DateTime.now().hour,
        'workloadLevel': _calculateCurrentWorkloadLevel(tasks),
        'stressLevel': _calculateCurrentStressLevel(tasks),
      },

      'taskAnalysis': _analyzeExistingTasksForAI(tasks),
      'availableTimeSlots': _calculateAvailableTimeSlots(tasks),

      'metadata': {
        'analysisTimestamp': DateTime.now().toIso8601String(),
        'dataQualityScore': 0.5,
        'confidenceLevel': 0.6,
        'isBasicContext': true,
      },
    };
  }

// 헬퍼 함수들
  String _getTimeOfDayCategory(int hour) {
    if (hour >= 6 && hour <= 11) return 'morning';
    if (hour >= 12 && hour <= 17) return 'afternoon';
    if (hour >= 18 && hour <= 22) return 'evening';
    return 'night';
  }

  String _getWeekPosition(int weekday) {
    if (weekday <= 2) return 'early_week';
    if (weekday <= 4) return 'mid_week';
    return 'late_week';
  }

  String _getMonthPosition(int day) {
    if (day <= 10) return 'early_month';
    if (day <= 20) return 'mid_month';
    return 'late_month';
  }

  String _getYearPosition(int month) {
    if (month <= 3) return 'early_year';
    if (month <= 6) return 'mid_year';
    if (month <= 9) return 'late_year';
    return 'end_year';
  }

  String _getBiorhythmPhase(int hour) {
    if (hour >= 6 && hour <= 10) return 'rising';
    if (hour >= 11 && hour <= 15) return 'peak';
    if (hour >= 16 && hour <= 20) return 'declining';
    return 'rest';
  }

  String _getSocialRhythm(int hour, int weekday) {
    final isWeekend = weekday >= 6;

    if (isWeekend) {
      if (hour >= 9 && hour <= 12) return 'weekend_morning';
      if (hour >= 13 && hour <= 18) return 'weekend_afternoon';
      return 'weekend_evening';
    } else {
      if (hour >= 7 && hour <= 9) return 'commute_time';
      if (hour >= 10 && hour <= 17) return 'work_hours';
      if (hour >= 18 && hour <= 20) return 'personal_time';
      return 'rest_time';
    }
  }

  // 1. 사용자 학습 데이터 로드
  Future<Map<String, dynamic>> _loadUserLearningData() async {
    try {
      // Firestore에서 사용자별 학습 데이터 로드
      final learningDoc = await FirebaseFirestore.instance
          .collection('user_learning_data')
          .doc(userId)
          .get();

      if (learningDoc.exists) {
        final data = learningDoc.data() as Map<String, dynamic>;
        print('📚 사용자 학습 데이터 로드: ${data.keys.length}개 패턴');
        return data;
      }

      // 새 사용자인 경우 기본 학습 데이터 생성
      return await _initializeUserLearningData();
    } catch (e) {
      print('학습 데이터 로드 오류: $e');
      return await _initializeUserLearningData();
    }
  }

// 2. 사용자 학습 데이터 초기화
  Future<Map<String, dynamic>> _initializeUserLearningData() async {
    final initialData = {
      'userId': userId,
      'adaptationLevel': 0.0,
      'totalRecommendations': 0,
      'acceptedRecommendations': 0,
      'completionPatterns': {
        'morningSuccess': 0.8,
        'afternoonSuccess': 0.7,
        'eveningSuccess': 0.6,
        'categoryPreferences': <String, double>{},
        'timeSlotEffectiveness': <String, double>{},
      },
      'behaviorPatterns': {
        'preferredTaskDurations': <String, int>{},
        'categoryTimePreferences': <String, List<int>>{},
        'workloadToleranceLevel': 'medium',
        'breakPreferences': <String, dynamic>{},
      },
      'contextualLearning': {
        'seasonalPatterns': <String, dynamic>{},
        'weekdayPatterns': <String, dynamic>{},
        'stressResponsePatterns': <String, dynamic>{},
      },
      'feedbackHistory': <Map<String, dynamic>>[],
      'lastUpdated': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('user_learning_data')
          .doc(userId)
          .set(initialData);
      print('✅ 사용자 학습 데이터 초기화 완료');
    } catch (e) {
      print('학습 데이터 초기화 오류: $e');
    }

    return initialData;
  }

// 3. 사용자 완료 패턴 심층 분석
  Future<Map<String, dynamic>> _analyzeUserCompletionHistory() async {
    try {
      final now = DateTime.now();
      final patterns = <String, dynamic>{
        'dailyCompletionRates': <String, double>{},
        'categorySuccessRates': <String, double>{},
        'timeSlotEffectiveness': <int, double>{},
        'weeklyTrends': <String, double>{},
        'seasonalPatterns': <String, double>{},
        'stressLevelImpact': <String, double>{},
        'taskComplexityHandling': <String, double>{},
      };

      // 최근 60일간의 완료 데이터 심층 분석
      final completionData = <Map<String, dynamic>>[];

      for (int i = 0; i < 60; i++) {
        final date = now.subtract(Duration(days: i));
        final dayTasks = _taskDataService.getTodoTasksForDate(date);
        final plannerTasks = _taskDataService.getPlannerTasksForDate(date);
        final allTasks = [...dayTasks, ...plannerTasks];

        if (allTasks.isNotEmpty) {
          final completed = allTasks.where((task) => task.isCompleted).length;
          final total = allTasks.length;
          final completionRate = completed / total;

          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          patterns['dailyCompletionRates'][dateKey] = completionRate;

          // 요일별 성공률 분석
          final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
          final weekdayKey = weekdayNames[date.weekday - 1];

          if (!patterns['weeklyTrends'].containsKey(weekdayKey)) {
            patterns['weeklyTrends'][weekdayKey] = <double>[];
          }
          (patterns['weeklyTrends'][weekdayKey] as List<double>).add(completionRate);

          // 카테고리별 성공률 분석
          final categoryStats = <String, Map<String, int>>{};
          for (var task in allTasks) {
            final category = _getTaskType(task.title);
            if (!categoryStats.containsKey(category)) {
              categoryStats[category] = {'total': 0, 'completed': 0};
            }
            categoryStats[category]!['total'] = categoryStats[category]!['total']! + 1;
            if (task.isCompleted) {
              categoryStats[category]!['completed'] = categoryStats[category]!['completed']! + 1;
            }
          }

          // 시간대별 효율성 분석
          final hourlyStats = <int, Map<String, int>>{};
          for (var task in allTasks) {
            if (task.time != null) {
              try {
                final hour = _parseTimeToHour(task.time!);
                if (!hourlyStats.containsKey(hour)) {
                  hourlyStats[hour] = {'total': 0, 'completed': 0};
                }
                hourlyStats[hour]!['total'] = hourlyStats[hour]!['total']! + 1;
                if (task.isCompleted) {
                  hourlyStats[hour]!['completed'] = hourlyStats[hour]!['completed']! + 1;
                }
              } catch (e) {
                // 시간 파싱 실패 시 무시
              }
            }
          }

          completionData.add({
            'date': dateKey,
            'completionRate': completionRate,
            'categoryStats': categoryStats,
            'hourlyStats': hourlyStats,
            'totalTasks': total,
            'weekday': date.weekday,
            'isWeekend': date.weekday >= 6,
          });
        }
      }

      // 요일별 평균 계산
      patterns['weeklyTrends'].forEach((weekday, rates) {
        if (rates is List<double> && rates.isNotEmpty) {
          patterns['weeklyTrends'][weekday] = rates.reduce((a, b) => a + b) / rates.length;
        }
      });

      // 카테고리별 성공률 집계
      final globalCategoryStats = <String, Map<String, int>>{};
      for (var dayData in completionData) {
        final categoryStats = dayData['categoryStats'] as Map<String, Map<String, int>>;
        categoryStats.forEach((category, stats) {
          if (!globalCategoryStats.containsKey(category)) {
            globalCategoryStats[category] = {'total': 0, 'completed': 0};
          }
          globalCategoryStats[category]!['total'] = globalCategoryStats[category]!['total']! + stats['total']!;
          globalCategoryStats[category]!['completed'] = globalCategoryStats[category]!['completed']! + stats['completed']!;
        });
      }

      globalCategoryStats.forEach((category, stats) {
        if (stats['total']! > 0) {
          patterns['categorySuccessRates'][category] = stats['completed']! / stats['total']!;
        }
      });

      // 시간대별 효율성 집계
      final globalHourlyStats = <int, Map<String, int>>{};
      for (var dayData in completionData) {
        final hourlyStats = dayData['hourlyStats'] as Map<int, Map<String, int>>;
        hourlyStats.forEach((hour, stats) {
          if (!globalHourlyStats.containsKey(hour)) {
            globalHourlyStats[hour] = {'total': 0, 'completed': 0};
          }
          globalHourlyStats[hour]!['total'] = globalHourlyStats[hour]!['total']! + stats['total']!;
          globalHourlyStats[hour]!['completed'] = globalHourlyStats[hour]!['completed']! + stats['completed']!;
        });
      }

      globalHourlyStats.forEach((hour, stats) {
        if (stats['total']! > 0) {
          patterns['timeSlotEffectiveness'][hour] = stats['completed']! / stats['total']!;
        }
      });

      print('📊 완료 패턴 심층 분석 완료: ${completionData.length}일 데이터');
      print('📈 카테고리별 성공률: ${patterns['categorySuccessRates']}');
      print('⏰ 시간대별 효율성: ${patterns['timeSlotEffectiveness']}');

      return patterns;

    } catch (e) {
      print('완료 패턴 분석 오류: $e');
      return {
        'dailyCompletionRates': <String, double>{},
        'categorySuccessRates': <String, double>{},
        'timeSlotEffectiveness': <int, double>{},
        'weeklyTrends': <String, double>{},
      };
    }
  }

// _analyzeTimePreferences 함수를 다음과 같이 수정
  List<String> _analyzeTimePreferences([List<Todo_Task>? tasks]) {
    final targetTasks = tasks ?? _taskDataService.getTodoTasksForDate(selectedDate);

    final hourCounts = <String, int>{
      '아침': 0,  // 6-11시
      '오후': 0,  // 12-17시
      '저녁': 0,  // 18-22시
    };

    for (final task in targetTasks) {
      if (task.time != null && task.time!.isNotEmpty) {
        try {
          final hour = _parseTimeToHour(task.time!);
          if (hour >= 6 && hour <= 11) {
            hourCounts['아침'] = hourCounts['아침']! + 1;
          } else if (hour >= 12 && hour <= 17) {
            hourCounts['오후'] = hourCounts['오후']! + 1;
          } else if (hour >= 18 && hour <= 22) {
            hourCounts['저녁'] = hourCounts['저녁']! + 1;
          }
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }

    // 선호도 순으로 정렬
    final sortedPrefs = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final preferences = <String>[];
    for (final entry in sortedPrefs) {
      if (entry.value > 0) {
        preferences.add(entry.key);
      }
    }

    return preferences.isNotEmpty ? preferences : ['아침'];
  }

// 5. 사용자 행동 패턴 업데이트
  Future<void> _updateUserBehaviorPatterns(List<TaskRecommendation> recommendations) async {
    try {
      final currentLearningData = await _loadUserLearningData();

      // 추천 수락률 업데이트
      currentLearningData['totalRecommendations'] = (currentLearningData['totalRecommendations'] ?? 0) + recommendations.length;

      // 적응 레벨 계산 (추천 수 기반으로 경험치 증가)
      final currentLevel = currentLearningData['adaptationLevel'] ?? 0.0;
      final experienceGain = recommendations.length * 0.05; // 추천 1개당 5% 경험치
      currentLearningData['adaptationLevel'] = (currentLevel + experienceGain).clamp(0.0, 1.0);

      // 행동 패턴 기록
      final behaviorEvent = {
        'timestamp': DateTime.now().toIso8601String(),
        'recommendationCount': recommendations.length,
        'averageConfidence': recommendations.map((r) => r.confidence).reduce((a, b) => a + b) / recommendations.length,
        'categories': recommendations.map((r) => _inferCategoryFromTitle(r.taskTitle)).toSet().toList(),
        'timeSlots': recommendations.map((r) => r.recommendedTime).toList(),
      };

      if (currentLearningData['feedbackHistory'] == null) {
        currentLearningData['feedbackHistory'] = <Map<String, dynamic>>[];
      }
      (currentLearningData['feedbackHistory'] as List<Map<String, dynamic>>).add(behaviorEvent);

      // 최근 50개만 유지
      if ((currentLearningData['feedbackHistory'] as List).length > 50) {
        (currentLearningData['feedbackHistory'] as List).removeAt(0);
      }

      currentLearningData['lastUpdated'] = DateTime.now().toIso8601String();

      // Firestore에 저장
      await FirebaseFirestore.instance
          .collection('user_learning_data')
          .doc(userId)
          .set(currentLearningData, SetOptions(merge: true));

      print('🧠 사용자 행동 패턴 업데이트 완료: 적응도 ${currentLearningData['adaptationLevel']}');

    } catch (e) {
      print('행동 패턴 업데이트 오류: $e');
    }
  }

// 6. 추천 이벤트 기록
  Future<void> _recordRecommendationEvent(int recommendationCount, bool aiServerUsed) async {
    try {
      await FirebaseFirestore.instance
          .collection('recommendation_events')
          .add({
        'userId': userId,
        'date': selectedDate.toIso8601String().split('T')[0],
        'recommendationCount': recommendationCount,
        'aiServerUsed': aiServerUsed,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': 'flutter',
          'version': '1.0.0',
        },
      });

      print('📝 추천 이벤트 기록 완료: ${recommendationCount}개 추천, AI서버: $aiServerUsed');
    } catch (e) {
      print('추천 이벤트 기록 오류: $e');
    }
  }

  // AI 모델 심층 분석 요청 함수
  Future<List<TaskRecommendation>> _requestDeepAIAnalysis({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      const String endpoint = '/api/contextual-recommendations';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('🤖 AI 모델 심층 분석 요청 시작: $fullUrl');

      // 1. 기존 태스크를 AI 분석용으로 상세 변환
      final analyzedTasks = existingTasks.map((task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description ?? '',
        'time': task.time,
        'endTime': task.endTime,
        'startTime': task.time,
        'importance': task.importance,
        'urgency': task.urgency,
        'category': _getTaskType(task.title),
        'location': task.location ?? '',
        'memo': task.memo ?? '',
        'isCompleted': task.isCompleted,
        'date': task.date.toIso8601String(),
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating,
        'prerequisites': null,

        // AI 분석을 위한 추가 메타데이터
        'estimatedDuration': _calculateTaskDuration(task),
        'focusRequirement': _calculateFocusRequirement(task),
        'timeFlexibility': _calculateTimeFlexibility(task),
        'semanticKeywords': _extractSemanticKeywords(task.title, task.description),
        'userHistoryMatch': _findSimilarTasksInHistory(task),
        'contextualRelations': _analyzeTaskRelations(task, existingTasks),
        'stressIndicator': _calculateTaskStressLevel(task),
        'collaborationLevel': _assessCollaborationRequirement(task),
        'energyRequirement': _assessEnergyRequirement(task),
      }).toList();

      // 2. 고도화된 요청 데이터 구성
      final requestData = {
        'userId': userContext['userId'],
        'existingTasks': analyzedTasks,
        'userContext': userContext,
        'maxRecommendations': 7, // 더 많은 추천 요청
        'analysisDepth': 'deep_contextual_learning',
        'enableLearning': true,
        'requestType': 'intelligent_contextual',

        // 추가 분석 옵션
        'analysisOptions': {
          'includeSemanticAnalysis': true,
          'includeTemporalPatterns': true,
          'includeBehaviorLearning': true,
          'includeStressOptimization': true,
          'includeEnergyManagement': true,
          'includeWorkflowAnalysis': true,
        },

        // 세션 정보
        'sessionInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'timezone': 'Asia/Seoul',
          'deviceType': 'mobile',
          'sessionId': '${userId}_${DateTime.now().millisecondsSinceEpoch}',
        },
      };

      print('📤 상세 분석 데이터 전송 중...');
      print('📊 분석할 태스크: ${analyzedTasks.length}개');
      print('🧠 사용자 학습 레벨: ${userContext['userLearningData']?['adaptationLevel'] ?? 0.0}');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'MomentumPlanner/2.0',
          'X-Analysis-Type': 'deep_learning',
          'X-User-Adaptation-Level': '${userContext['userLearningData']?['adaptationLevel'] ?? 0.0}',
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 45)); // 더 긴 타임아웃

      print('📥 AI 모델 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['recommendations'] != null) {
          final recommendations = responseData['recommendations'] as List;
          final modelUsed = responseData['method'] ?? 'unknown';
          final aiConfidence = responseData['overall_confidence'] ?? 0.7;
          final learningUpdate = responseData['learning_updated'] ?? false;

          print('✅ AI 모델 심층 분석 성공: ${recommendations.length}개');
          print('🎯 분석 방식: $modelUsed');
          print('📊 전체 신뢰도: ${(aiConfidence * 100).toInt()}%');
          print('🧠 학습 업데이트: $learningUpdate');

          // 3. 추천을 TaskRecommendation 객체로 변환 (고도화된 메타데이터 포함)
          final result = recommendations.map((rec) {
            final recommendation = TaskRecommendation(
              taskId: rec['taskId']?.toString() ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
              taskTitle: rec['taskTitle']?.toString() ?? '지능형 추천',
              recommendedTime: rec['recommendedTime']?.toString() ?? '09:00',
              confidence: (rec['confidence'] as num?)?.toDouble() ?? 0.7,
              reason: rec['reason']?.toString() ?? 'AI 모델 심층 분석 기반 맞춤 추천',
            );

            // 추가 메타데이터가 있다면 저장
            if (rec['metadata'] != null) {
              recommendation.metadata = Map<String, dynamic>.from(rec['metadata']);
            }

            // AI 분석 결과 추가
            recommendation.aiAnalysis = {
              'semanticSimilarity': rec['semantic_similarity'] ?? 0.0,
              'temporalFit': rec['temporal_fit'] ?? 0.0,
              'userPatternMatch': rec['user_pattern_match'] ?? 0.0,
              'stressOptimization': rec['stress_optimization'] ?? 0.0,
              'energyAlignment': rec['energy_alignment'] ?? 0.0,
              'learningWeight': rec['learning_weight'] ?? 0.0,
            };

            return recommendation;
          }).toList();

          // 4. 서버에서 학습 업데이트가 있었다면 로컬에도 적용
          if (learningUpdate && responseData['updated_learning_data'] != null) {
            await _applyServerLearningUpdate(responseData['updated_learning_data']);
          }

          // 5. 추천 품질 메트릭 기록
          await _recordRecommendationQuality(result, modelUsed, aiConfidence);

          return result;
        } else {
          throw Exception('AI 서버 응답 형식 오류: ${responseData['error'] ?? "알 수 없는 오류"}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ AI 모델 심층 분석 실패: $e');
      throw e;
    }
  }

// 헬퍼 함수들

// 1. 의미적 키워드 추출
  List<String> _extractSemanticKeywords(String title, String? description) {
    final text = '${title} ${description ?? ''}'.toLowerCase();
    final keywords = <String>[];

    // 도메인별 키워드 매핑
    final keywordGroups = {
      'travel': ['여행', 'travel', '항공', 'flight', '호텔', 'hotel', '출국', '비행기', '공항', '숙박'],
      'work': ['회의', 'meeting', '업무', 'work', '프로젝트', 'project', '발표', 'presentation', '보고서'],
      'health': ['운동', 'exercise', '헬스', 'gym', '조깅', 'running', '요가', 'yoga', '병원', '건강'],
      'study': ['공부', 'study', '학습', '수업', 'class', '강의', '시험', 'exam', '과제', '독서'],
      'social': ['약속', '만남', 'appointment', '친구', 'friend', '가족', 'family', '데이트', '모임'],
      'household': ['청소', 'cleaning', '요리', 'cooking', '쇼핑', 'shopping', '세탁', '정리'],
      'finance': ['은행', 'bank', '결제', '세금', 'tax', '투자', '보험', '대출'],
      'maintenance': ['수리', '점검', '교체', '설치', '관리', 'maintenance', '서비스'],
    };

    for (final entry in keywordGroups.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          keywords.add(entry.key);
          break;
        }
      }
    }

    return keywords.isEmpty ? ['general'] : keywords;
  }

// 2. 사용자 히스토리에서 유사한 태스크 찾기
  Map<String, dynamic> _findSimilarTasksInHistory(Todo_Task task) {
    try {
      final now = DateTime.now();
      final similarTasks = <Map<String, dynamic>>[];

      // 최근 30일간의 태스크 검색
      for (int i = 1; i <= 30; i++) {
        final pastDate = now.subtract(Duration(days: i));
        final pastTasks = _taskDataService.getTodoTasksForDate(pastDate);

        for (var pastTask in pastTasks) {
          final similarity = _calculateTaskSimilarity(task, pastTask);
          if (similarity > 0.6) {
            similarTasks.add({
              'title': pastTask.title,
              'similarity': similarity,
              'completed': pastTask.isCompleted,
              'daysAgo': i,
              'time': pastTask.time,
              'category': _getTaskType(pastTask.title),
            });
          }
        }
      }

      // 가장 유사한 상위 5개만 반환
      similarTasks.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

      return {
        'count': similarTasks.length,
        'averageSimilarity': similarTasks.isNotEmpty
            ? similarTasks.map((t) => t['similarity'] as double).reduce((a, b) => a + b) / similarTasks.length
            : 0.0,
        'averageCompletionRate': similarTasks.isNotEmpty
            ? similarTasks.where((t) => t['completed'] as bool).length / similarTasks.length
            : 0.0,
        'topMatches': similarTasks.take(5).toList(),
      };
    } catch (e) {
      return {'count': 0, 'averageSimilarity': 0.0, 'averageCompletionRate': 0.0, 'topMatches': []};
    }
  }

// 3. 태스크 유사도 계산
  double _calculateTaskSimilarity(Todo_Task task1, Todo_Task task2) {
    double similarity = 0.0;

    // 제목 유사도 (단어 기반)
    final title1Words = task1.title.toLowerCase().split(' ').toSet();
    final title2Words = task2.title.toLowerCase().split(' ').toSet();
    final commonWords = title1Words.intersection(title2Words);
    final titleSimilarity = commonWords.isNotEmpty
        ? (2.0 * commonWords.length) / (title1Words.length + title2Words.length)
        : 0.0;

    similarity += titleSimilarity * 0.4;

    // 카테고리 유사도
    if (_getTaskType(task1.title) == _getTaskType(task2.title)) {
      similarity += 0.3;
    }

    // 중요도/긴급도 유사도
    final importanceDiff = (task1.importance - task2.importance).abs();
    final urgencyDiff = (task1.urgency - task2.urgency).abs();
    similarity += (1.0 - (importanceDiff + urgencyDiff) / 10.0) * 0.2;

    // 시간대 유사도
    if (task1.time != null && task2.time != null) {
      try {
        final hour1 = _parseTimeToHour(task1.time!);
        final hour2 = _parseTimeToHour(task2.time!);
        final hourDiff = (hour1 - hour2).abs();
        similarity += (1.0 - hourDiff / 24.0) * 0.1;
      } catch (e) {
        // 시간 파싱 실패 시 무시
      }
    }

    return similarity.clamp(0.0, 1.0);
  }

// 4. 태스크 관계 분석
  Map<String, dynamic> _analyzeTaskRelations(Todo_Task task, List<Todo_Task> allTasks) {
    final relations = <String, dynamic>{
      'prerequisites': <String>[],
      'dependents': <String>[],
      'parallelTasks': <String>[],
      'conflictingTasks': <String>[],
      'synergisticTasks': <String>[],
    };

    final taskCategory = _getTaskType(task.title);
    final taskKeywords = _extractSemanticKeywords(task.title, task.description);

    for (var otherTask in allTasks) {
      if (otherTask.id == task.id) continue;

      final otherCategory = _getTaskType(otherTask.title);
      final otherKeywords = _extractSemanticKeywords(otherTask.title, otherTask.description);

      // 같은 카테고리의 유사한 태스크들
      if (taskCategory == otherCategory) {
        (relations['parallelTasks'] as List<String>).add(otherTask.title);
      }

      // 키워드 기반 시너지 태스크
      final commonKeywords = taskKeywords.toSet().intersection(otherKeywords.toSet());
      if (commonKeywords.isNotEmpty) {
        (relations['synergisticTasks'] as List<String>).add(otherTask.title);
      }

      // 시간 충돌 태스크
      if (task.time != null && otherTask.time != null) {
        try {
          final taskHour = _parseTimeToHour(task.time!);
          final otherHour = _parseTimeToHour(otherTask.time!);
          if ((taskHour - otherHour).abs() <= 1) {
            (relations['conflictingTasks'] as List<String>).add(otherTask.title);
          }
        } catch (e) {
          // 시간 파싱 실패 시 무시
        }
      }
    }

    return relations;
  }

// 5. 태스크 스트레스 레벨 계산
  double _calculateTaskStressLevel(Todo_Task task) {
    double stressLevel = 0.0;

    // 중요도/긴급도 기반 스트레스
    stressLevel += (task.importance + task.urgency) / 10.0;

    // 마감일 압박 스트레스
    if (task.dueDate != null) {
      final daysUntilDue = task.dueDate!.difference(DateTime.now()).inDays;
      if (daysUntilDue <= 1) {
        stressLevel += 0.4;
      } else if (daysUntilDue <= 3) {
        stressLevel += 0.2;
      }
    }

    // 복잡성 기반 스트레스
    final complexity = _calculateComplexityScore(task);
    stressLevel += complexity * 0.3;

    return stressLevel.clamp(0.0, 1.0);
  }

// 6. 협업 요구도 평가
  double _assessCollaborationRequirement(Todo_Task task) {
    final title = task.title.toLowerCase();
    final description = (task.description ?? '').toLowerCase();
    final combined = '$title $description';

    final collaborationKeywords = [
      '회의', 'meeting', '미팅', '발표', 'presentation', '팀', 'team',
      '함께', '공동', '협업', '그룹', 'group', '참석', '토론'
    ];

    double collaborationScore = 0.0;
    for (final keyword in collaborationKeywords) {
      if (combined.contains(keyword)) {
        collaborationScore += 0.2;
      }
    }

    return collaborationScore.clamp(0.0, 1.0);
  }

// 7. 에너지 요구도 평가
  double _assessEnergyRequirement(Todo_Task task) {
    final title = task.title.toLowerCase();
    final description = (task.description ?? '').toLowerCase();
    final combined = '$title $description';

    // 고에너지 키워드
    final highEnergyKeywords = [
      '운동', 'exercise', '프로젝트', 'project', '개발', '분석', 'analysis',
      '설계', '창작', '학습', 'study', '집중'
    ];

    // 저에너지 키워드
    final lowEnergyKeywords = [
      '휴식', 'break', '정리', '확인', 'check', '간단', '쉬운', '가벼운'
    ];

    double energyLevel = 0.5; // 기본값

    for (final keyword in highEnergyKeywords) {
      if (combined.contains(keyword)) {
        energyLevel += 0.15;
      }
    }

    for (final keyword in lowEnergyKeywords) {
      if (combined.contains(keyword)) {
        energyLevel -= 0.15;
      }
    }

    // 중요도/긴급도 반영
    energyLevel += (task.importance + task.urgency - 6) * 0.05;

    return energyLevel.clamp(0.0, 1.0);
  }

// 8. 서버 학습 업데이트 적용
  Future<void> _applyServerLearningUpdate(Map<String, dynamic> serverLearningData) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_learning_data')
          .doc(userId)
          .set(serverLearningData, SetOptions(merge: true));

      print('🔄 서버 학습 데이터 동기화 완료');
    } catch (e) {
      print('서버 학습 데이터 적용 오류: $e');
    }
  }

// 9. 추천 품질 메트릭 기록
  Future<void> _recordRecommendationQuality(
      List<TaskRecommendation> recommendations,
      String method,
      double confidence) async {
    try {
      final qualityMetrics = {
        'userId': userId,
        'date': selectedDate.toIso8601String().split('T')[0],
        'method': method,
        'overallConfidence': confidence,
        'recommendationCount': recommendations.length,
        'averageConfidence': recommendations.map((r) => r.confidence).reduce((a, b) => a + b) / recommendations.length,
        'confidenceDistribution': {
          'high': recommendations.where((r) => r.confidence >= 0.8).length,
          'medium': recommendations.where((r) => r.confidence >= 0.6 && r.confidence < 0.8).length,
          'low': recommendations.where((r) => r.confidence < 0.6).length,
        },
        'categories': recommendations.map((r) => _inferCategoryFromTitle(r.taskTitle)).toSet().toList(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('recommendation_quality_metrics')
          .add(qualityMetrics);

      print('📊 추천 품질 메트릭 기록 완료');
    } catch (e) {
      print('품질 메트릭 기록 오류: $e');
    }
  }

  // 향상된 사용자 컨텍스트 구성 (기존 일정 분석 포함)
  Future<Map<String, dynamic>> _buildEnhancedUserContextForAI(List<Todo_Task> allTasks) async {
    try {
      // 기본 사용자 선호도 가져오기
      final userPreferences = await _getUserPreferences();

      // 기존 일정 분석
      final taskAnalysis = _analyzeUserTaskPatterns(allTasks);

      // 최근 완료율 계산
      final recentCompletionRate = await _calculateRecentCompletionRate();

      // 생산성 점수 계산
      final productivityScore = await _calculateProductivityScore();

      // 현재 스트레스 레벨 계산
      final stressLevel = _calculateCurrentStressLevel();

      // 시간 선호도 분석
      final timePreferences = _analyzeTimePreferences(allTasks);

      return {
        'userId': userId,
        'sleepSchedule': userPreferences['sleepSchedule'] ?? 'PM 11:00 ~ AM 07:00',
        'breakFrequency': userPreferences['breakFrequency'] ?? '1시간마다',
        'recentCompletionRate': recentCompletionRate,
        'preferredTimeOfDay': timePreferences,
        'productivityScore': productivityScore,
        'stressLevel': stressLevel,
        'focusEnvironment': userPreferences['focusEnvironment'] ?? 'quiet',
        'workStyle': userPreferences['workStyle'] ?? 'balanced',
        'currentDate': selectedDate.toIso8601String().split('T')[0],
        'dayOfWeek': selectedDate.weekday,
        'timeZone': 'Asia/Seoul',
        'language': 'ko',
        'currentHour': DateTime.now().hour,
        'isWeekend': selectedDate.weekday >= 6,
        'totalTasksToday': allTasks.length,

        // 향상된 분석 결과 추가
        'taskAnalysis': taskAnalysis,
        'dominantCategories': taskAnalysis['dominantCategories'],
        'hasHighPriorityTasks': taskAnalysis['hasHighPriorityTasks'],
        'averageTaskDuration': taskAnalysis['averageTaskDuration'],
        'timeGaps': taskAnalysis['timeGaps'],
        'busyHours': taskAnalysis['busyHours'],
        'workloadLevel': taskAnalysis['workloadLevel'],
      };
    } catch (e) {
      print('향상된 사용자 컨텍스트 구성 오류: $e');
      // 기본값 반환
      return await _buildUserContextForAI();
    }
  }

// 사용자 태스크 패턴 분석
  Map<String, dynamic> _analyzeUserTaskPatterns(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'totalTasks': tasks.length,
      'dominantCategories': <String>[],
      'hasHighPriorityTasks': false,
      'averageTaskDuration': 60,
      'timeGaps': <String>[],
      'busyHours': <int>[],
      'workloadLevel': 'medium',
      'taskTypes': <String, int>{},
      'timeDistribution': <int, int>{},
    };

    if (tasks.isEmpty) return analysis;

    // 카테고리별 분석
    final categoryCount = <String, int>{};
    final priorityLevels = <int>[];
    final durations = <int>[];
    final hourDistribution = <int, int>{};

    for (final task in tasks) {
      // 카테고리 분석
      final category = _getTaskType(task.title);
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;

      // 우선순위 분석
      priorityLevels.add(task.importance);
      if (task.importance >= 4) {
        analysis['hasHighPriorityTasks'] = true;
      }

      // 시간 분석
      if (task.time != null && task.time!.isNotEmpty) {
        try {
          final hour = _parseTimeToHour(task.time!);
          hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
        } catch (e) {
          print('시간 파싱 오류: $e');
        }
      }

      // 소요시간 분석
      if (task.endTime != null && task.time != null) {
        try {
          final startHour = _parseTimeToHour(task.time!);
          final endHour = _parseTimeToHour(task.endTime!);
          durations.add((endHour - startHour) * 60);
        } catch (e) {
          durations.add(60); // 기본값
        }
      } else {
        durations.add(60); // 기본값
      }
    }

    // 지배적인 카테고리 찾기
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    analysis['dominantCategories'] = sortedCategories
        .take(3)
        .map((e) => e.key)
        .toList();

    // 평균 소요시간
    analysis['averageTaskDuration'] = durations.isNotEmpty
        ? durations.reduce((a, b) => a + b) / durations.length
        : 60;

    // 바쁜 시간대 찾기
    final busyHours = hourDistribution.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList()
      ..sort();
    analysis['busyHours'] = busyHours;

    // 시간 공백 찾기
    final timeGaps = <String>[];
    if (busyHours.isNotEmpty) {
      for (int hour = 9; hour <= 18; hour++) {
        if (!busyHours.contains(hour)) {
          timeGaps.add('${hour.toString().padLeft(2, '0')}:00');
        }
      }
    }
    analysis['timeGaps'] = timeGaps;

    // 작업량 레벨 계산
    if (tasks.length >= 8) {
      analysis['workloadLevel'] = 'high';
    } else if (tasks.length <= 3) {
      analysis['workloadLevel'] = 'low';
    } else {
      analysis['workloadLevel'] = 'medium';
    }

    analysis['taskTypes'] = categoryCount;
    analysis['timeDistribution'] = hourDistribution;

    return analysis;
  }

  // 향상된 AI 추천 요청
  Future<List<TaskRecommendation>> _requestEnhancedAIRecommendations({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      const String endpoint = '/ai_recommendation';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('🤖 향상된 AI 추천 요청 시작: $fullUrl');

      // 기존 태스크를 상세 분석하여 서버 형식으로 변환
      final analyzedTasks = existingTasks.map((task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description ?? '',
        'time': task.time,
        'endTime': task.endTime,
        'startTime': task.time,
        'importance': task.importance,
        'urgency': task.urgency,
        'category': _getTaskType(task.title),
        'location': task.location ?? '',
        'memo': task.memo ?? '',
        'isCompleted': task.isCompleted,
        'date': task.date.toIso8601String(),
        'dueDate': task.dueDate?.toIso8601String(),
        'isRepeating': task.isRepeating,
        'prerequisites': null,

        // 추가 분석 정보
        'estimatedDuration': _calculateTaskDuration(task),
        'focusRequirement': _calculateFocusRequirement(task),
        'timeFlexibility': _calculateTimeFlexibility(task),
        'relatedKeywords': _extractTaskKeywords(task.title, task.description),
      }).toList();

      final requestData = {
        'userId': userContext['userId'],
        'existingTasks': analyzedTasks,
        'userContext': userContext,
        'maxRecommendations': 5,
        'analysisDepth': 'detailed', // 상세 분석 요청
        'recommendationType': 'contextual', // 맥락적 추천
        'currentSession': {
          'date': selectedDate.toIso8601String().split('T')[0],
          'totalTasks': existingTasks.length,
          'dominantCategories': userContext['dominantCategories'],
          'timeGaps': userContext['timeGaps'],
          'workloadLevel': userContext['workloadLevel'],
        }
      };

      print('📤 상세 요청 데이터 전송');
      print('📤 태스크 분석: ${analyzedTasks.length}개');
      print('📤 지배 카테고리: ${userContext['dominantCategories']}');
      print('📤 작업량 레벨: ${userContext['workloadLevel']}');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'MomentumPlanner/1.0',
          'X-Analysis-Type': 'contextual',
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 30));

      print('📥 AI 서버 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['recommendations'] != null) {
          final recommendations = responseData['recommendations'] as List;
          final modelUsed = responseData['modelUsed'] ?? false;

          print('✅ 향상된 AI 추천 성공: ${recommendations.length}개 (AI 모델 사용: $modelUsed)');

          return recommendations.map((rec) => TaskRecommendation(
            taskId: rec['taskId']?.toString() ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
            taskTitle: rec['taskTitle']?.toString() ?? '맞춤 추천',
            recommendedTime: rec['recommendedTime']?.toString() ?? '09:00',
            confidence: (rec['confidence'] as num?)?.toDouble() ?? 0.7,
            reason: rec['reason']?.toString() ?? 'AI 상세 분석 기반 맞춤 추천',
          )).toList();
        } else {
          throw Exception('AI 서버 응답 형식 오류: ${responseData['error'] ?? "알 수 없는 오류"}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ 향상된 AI 추천 요청 실패: $e');
      throw e;
    }
  }

// 태스크 소요시간 계산
  int _calculateTaskDuration(Todo_Task task) {
    if (task.time != null && task.endTime != null) {
      try {
        final startHour = _parseTimeToHour(task.time!);
        final endHour = _parseTimeToHour(task.endTime!);
        return (endHour - startHour) * 60;
      } catch (e) {
        // 파싱 실패 시 기본값
      }
    }

    // 중요도/긴급도 기반 추정
    final priority = (task.importance + task.urgency) / 2;
    if (priority >= 4.5) return 120; // 2시간
    if (priority >= 3.5) return 90;  // 1.5시간
    return 60; // 1시간
  }

// 집중도 요구수준 계산
  double _calculateFocusRequirement(Todo_Task task) {
    final title = task.title.toLowerCase();
    final desc = (task.description ?? '').toLowerCase();
    final combined = '$title $desc';

    // 고집중 키워드
    final highFocusKeywords = ['공부', '학습', '프로그래밍', '설계', '분석', '연구', '개발', '작성'];
    final mediumFocusKeywords = ['회의', '계획', '정리', '검토', '준비', '발표'];
    final lowFocusKeywords = ['운동', '산책', '쇼핑', '청소', '휴식', '식사'];

    for (final keyword in highFocusKeywords) {
      if (combined.contains(keyword)) return 0.9;
    }

    for (final keyword in mediumFocusKeywords) {
      if (combined.contains(keyword)) return 0.6;
    }

    for (final keyword in lowFocusKeywords) {
      if (combined.contains(keyword)) return 0.3;
    }

    return 0.5; // 기본값
  }

// 시간 유연성 계산
  double _calculateTimeFlexibility(Todo_Task task) {
    double flexibility = 1.0;

    // 고정 시간이 있으면 유연성 낮음
    if (task.time != null && task.time!.isNotEmpty) {
      flexibility *= 0.3;
    }

    // 마감일이 있으면 유연성 낮음
    if (task.dueDate != null) {
      flexibility *= 0.5;
    }

    // 높은 우선순위면 유연성 낮음
    if (task.importance >= 4 || task.urgency >= 4) {
      flexibility *= 0.4;
    }

    return flexibility.clamp(0.0, 1.0);
  }

// 태스크 키워드 추출
  List<String> _extractTaskKeywords(String title, String? description) {
    final keywords = <String>[];
    final text = '${title} ${description ?? ''}'.toLowerCase();

    // 주요 키워드 매핑
    final keywordMap = {
      '여행': ['여행', 'travel', '항공', 'flight', '호텔', 'hotel', '출국', '비행기'],
      '회의': ['회의', 'meeting', '미팅', '발표', 'presentation'],
      '운동': ['운동', 'exercise', '헬스', 'gym', '조깅', 'running'],
      '공부': ['공부', 'study', '학습', '수업', 'class', '과제'],
      '쇼핑': ['쇼핑', 'shopping', '마트', '구매'],
      '의료': ['병원', '의료', '검진', '치료'],
      '업무': ['업무', 'work', '프로젝트', 'project', '개발'],
    };

    for (final entry in keywordMap.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          keywords.add(entry.key);
          break;
        }
      }
    }

    return keywords.isEmpty ? ['일반'] : keywords;
  }

  // 향상된 폴백 추천 생성 (AI 서버 실패 시)
  Future<List<TaskRecommendation>> _generateEnhancedFallbackRecommendations({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      final recommendations = <TaskRecommendation>[];
      final occupiedHours = <int>{};

      // 기존 일정 시간 수집
      for (var task in existingTasks) {
        if (task.time != null) {
          try {
            final hour = _parseTimeToHour(task.time!);
            occupiedHours.add(hour);
          } catch (e) {
            // 파싱 실패 시 무시
          }
        }
      }

      print('=== 향상된 폴백 추천 생성 ===');
      print('기존 태스크 수: ${existingTasks.length}');
      print('점유 시간: $occupiedHours');

      // 태스크 분석 결과 가져오기
      final taskAnalysis = userContext['taskAnalysis'] as Map<String, dynamic>;
      final dominantCategories = (userContext['dominantCategories'] as List<dynamic>).cast<String>();
      final workloadLevel = userContext['workloadLevel'] as String;

      // 카테고리별 맞춤 추천 생성
      final contextualSuggestions = <Map<String, dynamic>>[];

      // 1. 여행 관련 추천
      if (dominantCategories.contains('여행') || _hasKeyword(existingTasks, ['여행', 'travel', '항공', '출국'])) {
        contextualSuggestions.addAll([
          {
            'title': '여권 및 비자 서류 확인',
            'confidence': 0.95,
            'reason': '여행 일정 관련 필수 서류 사전 확인',
            'category': 'travel_prep',
            'preferredHours': [8, 9, 10, 19, 20],
            'priority': 0.9,
          },
          {
            'title': '항공편 체크인 및 좌석 선택',
            'confidence': 0.9,
            'reason': '원활한 출국을 위한 사전 체크인',
            'category': 'travel_prep',
            'preferredHours': [8, 9, 10],
            'priority': 0.85,
          },
          {
            'title': '현지 날씨 및 환율 확인',
            'confidence': 0.8,
            'reason': '여행지 현황 파악',
            'category': 'travel_prep',
            'preferredHours': [9, 10, 19, 20],
            'priority': 0.7,
          },
          {
            'title': '여행용 가방 및 필수품 체크리스트 작성',
            'confidence': 0.85,
            'reason': '체계적인 짐 준비를 위한 리스트',
            'category': 'travel_prep',
            'preferredHours': [15, 16, 17, 18],
            'priority': 0.8,
          },
        ]);
      }

      // 2. 업무/회의 관련 추천
      if (dominantCategories.contains('업무') || _hasKeyword(existingTasks, ['회의', 'meeting', '업무', '발표'])) {
        contextualSuggestions.addAll([
          {
            'title': '회의 자료 및 발표 준비',
            'confidence': 0.9,
            'reason': '효과적인 회의를 위한 사전 준비',
            'category': 'work_prep',
            'preferredHours': [8, 9, 17, 18],
            'priority': 0.9,
          },
          {
            'title': '참석자 명단 및 아젠다 확인',
            'confidence': 0.85,
            'reason': '회의 효율성 향상을 위한 사전 점검',
            'category': 'work_prep',
            'preferredHours': [8, 9, 18],
            'priority': 0.8,
          },
          {
            'title': '프로젝트 진행상황 점검',
            'confidence': 0.8,
            'reason': '업무 효율성 향상을 위한 중간 점검',
            'category': 'work_prep',
            'preferredHours': [9, 10, 14, 15],
            'priority': 0.75,
          },
        ]);
      }

      // 3. 운동 관련 추천
      if (dominantCategories.contains('운동') || _hasKeyword(existingTasks, ['운동', 'exercise', '헬스', '조깅'])) {
        contextualSuggestions.addAll([
          {
            'title': '운동복 및 운동화 준비',
            'confidence': 0.85,
            'reason': '효과적인 운동을 위한 장비 준비',
            'category': 'exercise_prep',
            'preferredHours': [7, 8, 17, 18, 19],
            'priority': 0.8,
          },
          {
            'title': '운동 전 워밍업 및 스트레칭',
            'confidence': 0.9,
            'reason': '부상 방지를 위한 사전 준비운동',
            'category': 'exercise_prep',
            'preferredHours': [7, 8, 18, 19],
            'priority': 0.85,
          },
          {
            'title': '물병 및 수건 챙기기',
            'confidence': 0.75,
            'reason': '운동 중 수분 보충 및 위생 관리',
            'category': 'exercise_prep',
            'preferredHours': [7, 8, 18, 19],
            'priority': 0.7,
          },
        ]);
      }

      // 4. 공부/학습 관련 추천
      if (dominantCategories.contains('공부') || _hasKeyword(existingTasks, ['공부', 'study', '학습', '수업'])) {
        contextualSuggestions.addAll([
          {
            'title': '교재 및 필기도구 준비',
            'confidence': 0.8,
            'reason': '효율적인 학습을 위한 도구 준비',
            'category': 'study_prep',
            'preferredHours': [9, 10, 14, 15],
            'priority': 0.8,
          },
          {
            'title': '조용한 학습 환경 조성',
            'confidence': 0.85,
            'reason': '집중력 향상을 위한 환경 준비',
            'category': 'study_prep',
            'preferredHours': [8, 9, 19, 20],
            'priority': 0.75,
          },
          {
            'title': '이전 학습 내용 복습',
            'confidence': 0.9,
            'reason': '학습 효과 극대화를 위한 복습',
            'category': 'study_prep',
            'preferredHours': [19, 20, 21],
            'priority': 0.85,
          },
        ]);
      }

      // 5. 의료 관련 추천
      if (dominantCategories.contains('의료') || _hasKeyword(existingTasks, ['병원', '의료', '검진', '치료'])) {
        contextualSuggestions.addAll([
          {
            'title': '건강보험증 및 신분증 준비',
            'confidence': 0.9,
            'reason': '병원 방문을 위한 필수 서류 준비',
            'category': 'medical_prep',
            'preferredHours': [8, 9, 19, 20],
            'priority': 0.9,
          },
          {
            'title': '증상 및 문의사항 정리',
            'confidence': 0.85,
            'reason': '효과적인 진료를 위한 사전 준비',
            'category': 'medical_prep',
            'preferredHours': [19, 20, 21],
            'priority': 0.8,
          },
        ]);
      }

      // 6. 쇼핑 관련 추천
      if (dominantCategories.contains('쇼핑') || _hasKeyword(existingTasks, ['쇼핑', 'shopping', '마트', '구매'])) {
        contextualSuggestions.addAll([
          {
            'title': '쇼핑 리스트 작성',
            'confidence': 0.85,
            'reason': '효율적인 쇼핑을 위한 리스트 준비',
            'category': 'shopping_prep',
            'preferredHours': [8, 9, 19, 20],
            'priority': 0.8,
          },
          {
            'title': '예산 계획 및 할인 정보 확인',
            'confidence': 0.8,
            'reason': '경제적인 쇼핑을 위한 사전 조사',
            'category': 'shopping_prep',
            'preferredHours': [19, 20, 21],
            'priority': 0.7,
          },
        ]);
      }

      // 7. 작업량 기반 추천
      if (workloadLevel == 'high') {
        contextualSuggestions.addAll([
          {
            'title': '하루 일정 우선순위 재정리',
            'confidence': 0.8,
            'reason': '과도한 일정으로 인한 스트레스 관리',
            'category': 'planning',
            'preferredHours': [8, 12, 18],
            'priority': 0.85,
          },
          {
            'title': '중간 휴식 및 에너지 충전',
            'confidence': 0.9,
            'reason': '바쁜 일정 중 필수 휴식시간',
            'category': 'self_care',
            'preferredHours': [12, 13, 15, 17],
            'priority': 0.8,
          },
          {
            'title': '스트레스 해소 활동',
            'confidence': 0.75,
            'reason': '높은 작업량으로 인한 스트레스 관리',
            'category': 'self_care',
            'preferredHours': [17, 18, 20, 21],
            'priority': 0.7,
          },
        ]);
      } else if (workloadLevel == 'low') {
        contextualSuggestions.addAll([
          {
            'title': '추가 자기계발 시간',
            'confidence': 0.8,
            'reason': '여유로운 일정을 활용한 성장 기회',
            'category': 'self_improvement',
            'preferredHours': [14, 15, 16, 19, 20],
            'priority': 0.7,
          },
          {
            'title': '미뤄둔 일 정리',
            'confidence': 0.75,
            'reason': '여유 시간을 활용한 밀린 업무 처리',
            'category': 'planning',
            'preferredHours': [10, 11, 15, 16],
            'priority': 0.75,
          },
        ]);
      }

      // 8. 일반적인 생활 관리 추천 (항상 포함)
      contextualSuggestions.addAll([
        {
          'title': '내일 일정 미리 확인',
          'confidence': 0.7,
          'reason': '효율적인 하루 마무리 및 내일 준비',
          'category': 'planning',
          'preferredHours': [20, 21, 22],
          'priority': 0.6,
        },
        {
          'title': '오늘 하루 돌아보기',
          'confidence': 0.65,
          'reason': '성찰과 개선을 위한 하루 정리',
          'category': 'self_reflection',
          'preferredHours': [21, 22],
          'priority': 0.5,
        },
      ]);

      // 우선순위순으로 정렬
      contextualSuggestions.sort((a, b) => (b['priority'] as double).compareTo(a['priority'] as double));

      // 최대 5개까지 추천 생성
      for (int i = 0; i < contextualSuggestions.length && recommendations.length < 5; i++) {
        final suggestion = contextualSuggestions[i];
        final preferredHours = (suggestion['preferredHours'] as List<int>);

        // 최적 시간 찾기
        String optimalTime = '18:00'; // 기본값
        for (int hour in preferredHours) {
          if (!occupiedHours.contains(hour) && hour >= 6 && hour <= 22) {
            optimalTime = '${hour.toString().padLeft(2, '0')}:00';
            occupiedHours.add(hour); // 시간 점유 표시
            break;
          }
        }

        recommendations.add(TaskRecommendation(
          taskId: 'enhanced_fallback_${i}',
          taskTitle: suggestion['title'] as String,
          recommendedTime: optimalTime,
          confidence: suggestion['confidence'] as double,
          reason: suggestion['reason'] as String,
        ));
      }

      print('향상된 폴백 추천 생성 완료: ${recommendations.length}개');
      return recommendations;

    } catch (e) {
      print('향상된 폴백 추천 생성 오류: $e');
      return [];
    }
  }

// 키워드 존재 여부 확인 헬퍼 함수
  bool _hasKeyword(List<Todo_Task> tasks, List<String> keywords) {
    for (final task in tasks) {
      final text = '${task.title} ${task.description ?? ''}'.toLowerCase();
      for (final keyword in keywords) {
        if (text.contains(keyword.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }


  Future<Map<String, dynamic>> _collectUserBehaviorPatterns() async {
    try {
      // Firestore에서 사용자 행동 패턴 수집
      final behaviorSnapshot = await FirebaseFirestore.instance
          .collection('user_behavior_patterns')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final behaviorData = {
        'recentCompletions': <Map<String, dynamic>>[],
        'timePreferences': <String, int>{},
        'taskCategories': <String, int>{},
        'completionRates': <String, double>{},
      };

      for (var doc in behaviorSnapshot.docs) {
        final data = doc.data();

        // 완료된 작업 추가
        if (data['completionStatus'] == 'completed') {
          final recentCompletions = behaviorData['recentCompletions'] as List<Map<String, dynamic>>;
          recentCompletions.add({
            'taskType': data['taskType'],
            'timeSlot': data['timeSlot'],
            'importance': data['importance'],
            'completionTime': data['actualEndTime']?.toDate()?.toIso8601String(),
          });
        }

        // 시간 선호도 집계
        final timeSlot = data['timeSlot']?.toString() ?? '9';
        final timePreferences = behaviorData['timePreferences'] as Map<String, int>;
        timePreferences[timeSlot] = (timePreferences[timeSlot] ?? 0) + 1;

        // 작업 카테고리 집계
        final taskType = data['taskType']?.toString() ?? 'general';
        final taskCategories = behaviorData['taskCategories'] as Map<String, int>;
        taskCategories[taskType] = (taskCategories[taskType] ?? 0) + 1;
      }

      return behaviorData;
    } catch (e) {
      print('사용자 행동 패턴 수집 오류: $e');
      return {
        'recentCompletions': <Map<String, dynamic>>[],
        'timePreferences': <String, int>{},
        'taskCategories': <String, int>{},
        'completionRates': <String, double>{},
      };
    }
  }

  Map<String, dynamic> _convertTaskToApiFormat(Todo_Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description ?? '',
      'importance': task.importance,
      'urgency': task.urgency,
      'time': task.time,
      'endTime': task.endTime,
      'date': task.date.toIso8601String(),
      'category': _inferTaskCategory(task.title),
      'isCompleted': task.isCompleted,
      'estimatedDuration': _estimateTaskDuration(task),
      'dueDate': task.dueDate?.toIso8601String(),
      'location': task.location,
      'memo': task.memo,
    };
  }

  String _inferTaskCategory(String title) {
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('회의') || lowerTitle.contains('미팅') || lowerTitle.contains('meeting')) {
      return 'work';
    } else if (lowerTitle.contains('운동') || lowerTitle.contains('헬스') || lowerTitle.contains('exercise')) {
      return 'exercise';
    } else if (lowerTitle.contains('공부') || lowerTitle.contains('학습') || lowerTitle.contains('study')) {
      return 'study';
    } else if (lowerTitle.contains('식사') || lowerTitle.contains('점심') || lowerTitle.contains('meal')) {
      return 'personal';
    } else if (lowerTitle.contains('쇼핑') || lowerTitle.contains('마트') || lowerTitle.contains('shopping')) {
      return 'household';
    } else if (lowerTitle.contains('약속') || lowerTitle.contains('만남') || lowerTitle.contains('친구')) {
      return 'social';
    } else {
      return 'general';
    }
  }

  int _estimateTaskDuration(Todo_Task task) {
    if (task.time != null && task.endTime != null) {
      try {
        final startHour = _parseTimeToHour(task.time!);
        final endHour = _parseTimeToHour(task.endTime!);
        return (endHour - startHour) * 60; // 분 단위
      } catch (e) {
        // 파싱 실패 시 기본값
      }
    }

    // 중요도/긴급도 기반 추정
    final priority = (task.importance + task.urgency) / 2;
    if (priority >= 4) return 120; // 2시간
    if (priority >= 3) return 90;  // 1.5시간
    return 60; // 1시간
  }

  Map<String, dynamic> _analyzeExistingTasksAdvanced(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'categories': <String, int>{},
      'importanceDistribution': <int>[0, 0, 0, 0, 0], // 1-5
      'urgencyDistribution': <int>[0, 0, 0, 0, 0], // 1-5
      'timePatterns': <int, int>{},
      'taskComplexity': 0.0,
      'workload': 'medium',
    };

    int totalImportance = 0;
    int totalUrgency = 0;

    for (var task in tasks) {
      // 카테고리 분석
      final category = _inferTaskCategory(task.title);
      analysis['categories'][category] = (analysis['categories'][category] ?? 0) + 1;

      // 중요도/긴급도 분석
      final importance = task.importance.clamp(1, 5);
      final urgency = task.urgency.clamp(1, 5);

      analysis['importanceDistribution'][importance - 1]++;
      analysis['urgencyDistribution'][urgency - 1]++;

      totalImportance += importance;
      totalUrgency += urgency;

      // 시간 패턴 분석
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          analysis['timePatterns'][hour] = (analysis['timePatterns'][hour] ?? 0) + 1;
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }

    // 복잡도 계산
    if (tasks.isNotEmpty) {
      final avgImportance = totalImportance / tasks.length;
      final avgUrgency = totalUrgency / tasks.length;
      analysis['taskComplexity'] = (avgImportance + avgUrgency) / 10.0;

      // 작업량 평가
      if (tasks.length >= 8 || (avgImportance + avgUrgency) >= 8) {
        analysis['workload'] = 'high';
      } else if (tasks.length <= 3 || (avgImportance + avgUrgency) <= 4) {
        analysis['workload'] = 'low';
      }
    }

    return analysis;
  }


  // 직접 AI 요청 (캘린더 포함)
  Future<List<TaskRecommendation>?> _tryDirectAIRequestWithCalendar(List<Map<String, dynamic>> allTasks) async {
    try {
      final String serverUrl = 'https://railwavve-production-68d4.up.railway.app/predict_schedule';

      final requestBody = {
        'userId': userId,
        'tasks': allTasks,
        'date': selectedDate.toIso8601String().split('T')[0],
        'userContext': {
          'sleepSchedule': 'PM 11:00 ~ AM 07:00',
          'breakFrequency': '1시간마다',
          'recentCompletionRate': 0.8,
          'preferredTimeOfDay': ['아침'],
          'productivityScore': 0.75,
          'stressLevel': 3,
          'focusEnvironment': 'quiet'
        }
      };

      print('=== 캘린더 포함 AI 요청 ===');
      print('URL: $serverUrl');
      print('총 태스크 수: ${allTasks.length}');
      print('투두 태스크: ${allTasks.where((t) => t['source'] == 'todo').length}개');
      print('캘린더 이벤트: ${allTasks.where((t) => t['source'] == 'calendar').length}개');

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      print('응답 상태: ${response.statusCode}');
      print('응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['predictions'] != null) {
          final predictions = responseData['predictions'] as List;

          return predictions.map((prediction) => TaskRecommendation(
            taskId: prediction['taskId']?.toString() ?? '',
            taskTitle: prediction['taskTitle']?.toString() ?? '',
            recommendedTime: prediction['recommendedTime']?.toString() ?? '09:00',
            confidence: (prediction['confidence'] as num?)?.toDouble() ?? 0.7,
            reason: prediction['reason']?.toString() ?? 'AI 최적화 (캘린더 포함)',
          )).toList();
        } else {
          print('AI 서버 응답 오류: ${responseData['error'] ?? "알 수 없는 오류"}');
          return null;
        }
      } else {
        print('HTTP 오류: ${response.statusCode}');
        return null;
      }

    } catch (e) {
      print('캘린더 포함 AI 요청 실패: $e');
      return null;
    }
  }

// 기본 스케줄 생성 (캘린더 포함)
  List<TaskRecommendation> _generateBasicScheduleWithCalendar(List<Todo_Task> todoTasks, List<Map<String, dynamic>> calendarEvents) {
    List<TaskRecommendation> recommendations = [];
    Set<int> occupiedHours = {};

    print('=== 기본 스케줄 생성 (캘린더 포함) ===');
    print('투두 태스크: ${todoTasks.length}개');
    print('캘린더 이벤트: ${calendarEvents.length}개');

    // 1. 캘린더 이벤트 먼저 고정 배치
    for (var event in calendarEvents) {
      if (event['startTime'] != null && event['startTime'].toString().isNotEmpty) {
        try {
          final startHour = int.parse(event['startTime'].split(':')[0]);
          final duration = (event['estimatedDuration'] ?? 60) ~/ 60; // 시간 단위로 변환

          // 시간대 점유 표시
          for (int h = startHour; h < startHour + duration && h < 24; h++) {
            occupiedHours.add(h);
          }

          // 캘린더 이벤트 추천 추가
          recommendations.add(TaskRecommendation(
            taskId: event['id'],
            taskTitle: '📅 ${event['title']}',
            recommendedTime: _convertTo24HourFormat(event['startTime']),
            confidence: 0.95, // 캘린더 일정은 높은 신뢰도
            reason: '캘린더에서 가져온 고정 일정',
          ));

          print('캘린더 이벤트 배치: ${event['title']} at ${event['startTime']}');
        } catch (e) {
          print('캘린더 이벤트 시간 파싱 오류: $e');
        }
      }
    }

    // 2. 투두 태스크를 중요도/긴급도 순으로 정렬
    final sortedTasks = List<Todo_Task>.from(todoTasks);
    sortedTasks.sort((a, b) => (b.importance + b.urgency).compareTo(a.importance + a.urgency));

    // 3. 시간이 지정된 투두 태스크 먼저 배치
    for (var task in sortedTasks) {
      if (task.time != null && task.time!.isNotEmpty) {
        try {
          final timeHour = _parseTimeToHour(task.time!);

          if (!occupiedHours.contains(timeHour)) {
            occupiedHours.add(timeHour);

            recommendations.add(TaskRecommendation(
              taskId: task.id,
              taskTitle: task.title,
              recommendedTime: _convertTimeToHHMM(task.time!),
              confidence: 0.8,
              reason: '사용자 지정 시간 반영, 중요도 ${task.importance}',
            ));

            // 처리됨 표시
            task.memo = (task.memo ?? '') + '[PROCESSED]';
          }
        } catch (e) {
          print('투두 시간 파싱 오류: $e');
        }
      }
    }

    // 4. 남은 투두 태스크들을 빈 시간대에 배치
    int currentHour = 9; // 오전 9시부터 시작

    for (var task in sortedTasks) {
      // 이미 처리된 태스크는 건너뛰기
      if (task.memo?.contains('[PROCESSED]') == true) continue;
      if (currentHour >= 18) break; // 오후 6시까지만

      // 사용 가능한 시간 찾기
      while (occupiedHours.contains(currentHour) && currentHour < 18) {
        currentHour++;
      }

      if (currentHour < 18) {
        occupiedHours.add(currentHour);

        // 중요도/긴급도 기반 신뢰도 계산
        double confidence = ((task.importance + task.urgency) / 10.0).clamp(0.6, 0.9);

        recommendations.add(TaskRecommendation(
          taskId: task.id,
          taskTitle: task.title,
          recommendedTime: '${currentHour.toString().padLeft(2, '0')}:00',
          confidence: confidence,
          reason: '중요도 ${task.importance}, 긴급도 ${task.urgency} 기반 최적 배치',
        ));

        currentHour++;
      }
    }

    print('기본 스케줄 생성 완료: 총 ${recommendations.length}개');
    print('캘린더: ${recommendations.where((r) => r.taskTitle.startsWith('📅')).length}개');
    print('투두: ${recommendations.where((r) => !r.taskTitle.startsWith('📅')).length}개');

    return recommendations;
  }

// 시간 형식 변환 헬퍼 함수들
  String _convertTo24HourFormat(String time) {
    if (time.contains(':')) {
      return time; // 이미 HH:mm 형식
    }
    return '${time.padLeft(2, '0')}:00';
  }

  String _convertTimeToHHMM(String timeString) {
    try {
      // "AM 09:00" -> "09:00"
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        if (timePart.contains(':')) {
          final parts = timePart.split(':');
          int hour = int.parse(parts[0].trim());
          final minute = parts[1].trim();

          // 12시간제를 24시간제로 변환
          if (!isAM && hour != 12) {
            hour += 12;
          } else if (isAM && hour == 12) {
            hour = 0;
          }

          return '${hour.toString().padLeft(2, '0')}:$minute';
        }
      }

      // 이미 24시간 형식이면 그대로 반환
      if (timeString.contains(':')) {
        return timeString;
      }

      return '09:00'; // 기본값
    } catch (e) {
      print('시간 변환 오류: $e');
      return '09:00';
    }
  }

  int _parseTimeToHour(String timeString) {
    try {
      // "AM 09:00" 형식 처리
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        int hour;
        if (timePart.contains(':')) {
          hour = int.parse(timePart.split(':')[0].trim());
        } else {
          hour = int.parse(timePart);
        }

        // 12시간제를 24시간제로 변환
        if (!isAM && hour != 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        return hour;
      }

      // "HH:mm" 형식 처리
      if (timeString.contains(':')) {
        return int.parse(timeString.split(':')[0]);
      }

      // 숫자만 있는 경우
      return int.parse(timeString);
    } catch (e) {
      print('시간 파싱 오류: $e');
      return 9; // 기본값
    }
  }



  List<TaskRecommendation> _generateBasicSchedule(List<Todo_Task> tasks) {
    List<TaskRecommendation> recommendations = [];
    int startHour = 9; // 오전 9시부터 시작

    // 중요도 + 긴급도 순으로 정렬
    final sortedTasks = List<Todo_Task>.from(tasks);
    sortedTasks.sort((a, b) => (b.importance + b.urgency).compareTo(a.importance + a.urgency));

    for (int i = 0; i < sortedTasks.length && startHour < 18; i++) {
      final task = sortedTasks[i];

      // 이미 시간이 정해진 작업은 그 시간 유지
      String recommendedTime;
      if (task.time != null && task.time!.isNotEmpty) {
        recommendedTime = _convertToHourMinute(task.time!);
      } else {
        recommendedTime = '${startHour.toString().padLeft(2, '0')}:00';
        startHour++;
      }

      // 중요도/긴급도 기반 신뢰도 계산
      double confidence = ((task.importance + task.urgency) / 10.0).clamp(0.6, 0.9);

      recommendations.add(TaskRecommendation(
        taskId: task.id,
        taskTitle: task.title,
        recommendedTime: recommendedTime,
        confidence: confidence,
        reason: '중요도 ${task.importance}, 긴급도 ${task.urgency} 기반 최적 배치',
      ));
    }

    return recommendations;
  }

  /// 시간 형식을 HH:mm으로 변환
  String _convertToHourMinute(String timeString) {
    try {
      // "AM 09:00" -> "09:00"
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        if (timePart.contains(':')) {
          final parts = timePart.split(':');
          int hour = int.parse(parts[0].trim());
          final minute = parts[1].trim();

          // 12시간제를 24시간제로 변환
          if (!isAM && hour != 12) {
            hour += 12;
          } else if (isAM && hour == 12) {
            hour = 0;
          }

          return '${hour.toString().padLeft(2, '0')}:$minute';
        }
      }

      // 이미 24시간 형식이면 그대로 반환
      if (timeString.contains(':')) {
        return timeString;
      }

      return '09:00'; // 기본값
    } catch (e) {
      print('시간 변환 오류: $e');
      return '09:00';
    }
  }




  String _formatAITimeToAppFormat(String aiTime) {
    final hour = int.parse(aiTime.split(':')[0]);
    final minute = aiTime.split(':')[1];

    if (hour < 12) {
      return 'AM ${hour.toString().padLeft(2, '0')}:$minute';
    } else if (hour == 12) {
      return 'PM 12:$minute';
    } else {
      return 'PM ${(hour - 12).toString().padLeft(2, '0')}:$minute';
    }
  }


  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // _buildPlannerView 함수 완전 수정
  Widget _buildPlannerView() {
    final tasks = _taskDataService.getPlannerTasksForDate(selectedDate);
    print('tasks length: ${tasks.length}');

    // 현재 날짜와 시간 정확히 가져오기
    final now = DateTime.now();
    final currentHour = now.hour;
    print('현재 시간: $currentHour시');

    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // 캘린더 및 투두리스트 정보 가져오기
    _fetchCalendarAndTodoCount();

    return Column(
      children: [
        // 상단 버튼 영역 (고정)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 캘린더 및 투두리스트 개수 정보 표시
              Text(
                '$_calendarCount Calendar and $_todoCount Task',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),

              // 일정 전체 삭제 버튼
              IconButton(
                onPressed: () {
                  // 확인 대화상자 표시
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('일정 초기화'),
                      content: const Text('이 날짜의 모든 일정을 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _taskDataService.clearPlannerTasksForDate(selectedDate);
                            setState(() {
                              updateProgress();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                tooltip: '모든 일정 삭제',
              ),
            ],
          ),
        ),

        // 시간별 일정 목록 - Flexible로 감싸서 남은 공간만 사용
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // 부모 스크롤뷰에 위임
            itemCount: 24,
            itemBuilder: (context, index) {
              final hour = index;
              final timeLabel = '${hour.toString().padLeft(2, '0')}:00';

              // 현재 시간에 해당하는지 확인
              final isCurrentHour = isToday && currentHour == hour;

              // 현재 시간대에 해당하는 일정들
              final hourTasks = tasks.where((task) {
                if (task.time == null || task.time!.isEmpty) return false;

                try {
                  // 24시간 형식 시간 (00:00)
                  if (task.time!.contains(':') && !task.time!.contains('AM') && !task.time!.contains('PM')) {
                    final parts = task.time!.split(':');
                    if (parts.length == 2) {
                      final taskHour = int.parse(parts[0]);
                      return taskHour == hour;
                    }
                  }

                  // AM/PM 형식 시간
                  if (task.time!.contains('AM') || task.time!.contains('PM')) {
                    final isPM = task.time!.contains('PM');
                    final timePart = task.time!.replaceAll('AM', '').replaceAll('PM', '').trim();
                    final timeParts = timePart.split(':');
                    if (timeParts.length >= 1) {
                      int taskHour = int.parse(timeParts[0].trim());
                      if (isPM && taskHour < 12) taskHour += 12;
                      if (!isPM && taskHour == 12) taskHour = 0;
                      return taskHour == hour;
                    }
                  }
                } catch (e) {
                  print('시간 파싱 오류: $e');
                }

                return false;
              }).toList();

              // 전체 시간 행 - 시간 표시와 일정 영역을 함께 표시
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 왼쪽 시간 표시
                    Container(
                      width: 60,
                      constraints: BoxConstraints(minHeight: 70),
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(left: 10, top: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        color: isCurrentHour
                            ? Colors.purple.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.03),
                      ),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentHour
                              ? Colors.purple.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),

                    // 오른쪽 일정 영역
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(minHeight: 70),
                        decoration: BoxDecoration(
                          color: isCurrentHour ? Colors.purple.withOpacity(0.05) : Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: isCurrentHour ? Colors.purple.shade400 : Colors.transparent,
                              width: isCurrentHour ? 3 : 0,
                            ),
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: hourTasks.isEmpty
                            ? Container() // 빈 시간대
                            : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: hourTasks.map((task) => _buildTodoTaskCard(task)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

// 멤버 변수 추가
  int _calendarCount = 0;
  int _todoCount = 0;


  void _fetchCalendarAndTodoCount() async {
    try {
      //print('=== 캘린더 카운트 디버깅 시작 ===');
      //print('사용자 ID: "$userId"');
      //print('사용자 ID 길이: ${userId.length}');
      //print('widget.userId: "${widget.userId}"');

      // userId 최종 검증
      if (userId.isEmpty) {
        // Arguments에서 다시 한번 시도
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args['userId'] != null) {
          userId = args['userId'].toString();
          _taskDataService.setUserId(userId);
          print('✅ Arguments에서 userId 재설정: "$userId"');
        } else if (widget.userId != null && widget.userId!.isNotEmpty) {
          userId = widget.userId!;
          _taskDataService.setUserId(userId);
          print('✅ widget.userId로 재설정: "$userId"');
        } else {
          print('❌ userId를 어디서도 찾을 수 없음');
          return;
        }
      }

      // 나머지 함수 내용은 동일...
      final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      int calendarCount = 0;

      //print('선택된 날짜: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}');
      //print('투두 태스크 수: ${todoTasks.length}');

      try {
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('userId', isEqualTo: userId)
            .get();

        //print('전체 이벤트 문서 수: ${eventsSnapshot.docs.length}');

        for (int i = 0; i < eventsSnapshot.docs.length; i++) {
          var doc = eventsSnapshot.docs[i];
          try {
            final data = doc.data();
            //print('\n--- 이벤트 $i ---');
            //print('문서 ID: ${doc.id}');
            //print('제목: ${data['title']}');
            //print('이벤트 userId: ${data['userId']}');
            //print('현재 userId: $userId');
            //print('일치 여부: ${data['userId'] == userId}');

            if (data['startDate'] != null) {
              DateTime eventDate;

              if (data['startDate'] is Timestamp) {
                eventDate = (data['startDate'] as Timestamp).toDate();
              } else if (data['startDate'] is String) {
                eventDate = DateTime.parse(data['startDate']);
              } else {
                continue;
              }

              if (eventDate.year == selectedDate.year &&
                  eventDate.month == selectedDate.month &&
                  eventDate.day == selectedDate.day) {
                calendarCount++;
                //print('✅ 매칭! 현재 카운트: $calendarCount');
              }
            }
          } catch (e) {
            print('❌ 개별 이벤트 처리 오류: $e');
            continue;
          }
        }
      } catch (e) {
        print('❌ 캘린더 이벤트 쿼리 오류: $e');
        calendarCount = 0;
      }

      //print('\n=== 최종 결과 ===');
      //print('캘린더 이벤트 수: $calendarCount');
      //print('투두 태스크 수: ${todoTasks.length}');

      if (mounted) {
        setState(() {
          _calendarCount = calendarCount;
          _todoCount = todoTasks.length;
        });
      }
    } catch (e) {
      print('❌ 전체 함수 오류: $e');
    }
  }

// 추가로 캘린더 이벤트 존재 여부를 직접 확인하는 함수
  Future<void> _debugCalendarEvents() async {
    try {
      //print('\n=== 전체 캘린더 이벤트 디버깅 ===');

      // 모든 이벤트를 가져와서 확인
      final allEventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();

      //print('전체 이벤트 컬렉션의 문서 수: ${allEventsSnapshot.docs.length}');

      for (var doc in allEventsSnapshot.docs) {
        final data = doc.data();
        //print('문서: ${doc.id}');
        //print('  userId: ${data['userId']}');
        //print('  title: ${data['title']}');
        //print('  startDate: ${data['startDate']}');
        //print('  현재 사용자와 일치: ${data['userId'] == userId}');
        //print('');
      }

      // 현재 사용자의 이벤트만
      final userEventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      //print('현재 사용자($userId)의 이벤트 수: ${userEventsSnapshot.docs.length}');

    } catch (e) {
      print('디버깅 오류: $e');
    }
  }


  void changeSelectedDate(DateTime date) {
    setState(() {
      selectedDate = date;
      updateProgress();
    });

    // 캘린더 및 투두 개수 다시 가져오기
    _fetchCalendarAndTodoCount();
  }


// 3. 캘린더 이벤트를 AI용으로 로드하는 함수
  Future<List<Map<String, dynamic>>> _loadCalendarEventsForAI(DateTime date) async {
    List<Map<String, dynamic>> calendarEvents = [];

    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in eventsSnapshot.docs) {
        try {
          final data = doc.data();
          dynamic rawStartDate = data['startDate'];
          DateTime startDate;

          if (rawStartDate is Timestamp) {
            startDate = rawStartDate.toDate();
          } else if (rawStartDate is String) {
            startDate = DateTime.parse(rawStartDate);
          } else {
            continue;
          }

          // 날짜 비교
          if (startDate.year == date.year &&
              startDate.month == date.month &&
              startDate.day == date.day) {

            String? startTime;
            String? endTime;

            // 시작 시간 처리
            if (data['startTime'] != null) {
              final startTimeData = data['startTime'];
              if (startTimeData is Map<String, dynamic>) {
                final hour = startTimeData['hour'] ?? 0;
                final minute = startTimeData['minute'] ?? 0;
                startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
              }
            }

            // 종료 시간 처리
            if (data['endTime'] != null) {
              final endTimeData = data['endTime'];
              if (endTimeData is Map<String, dynamic>) {
                final hour = endTimeData['hour'] ?? 0;
                final minute = endTimeData['minute'] ?? 0;
                endTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
              }
            }

            calendarEvents.add({
              'id': 'cal_${doc.id}',
              'title': data['title'] ?? '제목 없음',
              'startTime': startTime,
              'endTime': endTime,
              'location': data['location'] ?? '',
              'memo': data['memo'] ?? '',
              'description': data['description'] ?? '',
              'type': 'calendar',
              'importance': 5,
              'urgency': 5,
            });
          }
        } catch (e) {
          print('캘린더 이벤트 처리 오류: $e');
          continue;
        }
      }

      print('AI용 캘린더 이벤트 로드 완료: ${calendarEvents.length}개');
      return calendarEvents;

    } catch (e) {
      print('AI용 캘린더 이벤트 로드 실패: $e');
      return [];
    }
  }

// 3. 헬퍼 함수들
  String _calculateEndTime(String startTime) {
    try {
      final parts = startTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // 1시간 후로 설정
      final endHour = (hour + 1) % 24;
      return '${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '10:00'; // 기본값
    }
  }

  int _calculateImportanceFromConfidence(double confidence) {
    if (confidence >= 0.9) return 5;
    if (confidence >= 0.8) return 4;
    if (confidence >= 0.7) return 3;
    if (confidence >= 0.6) return 2;
    return 1;
  }

  String _convertAITimeToAppFormat(String aiTime) {
    try {
      final parts = aiTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];

      if (hour < 12) {
        if (hour == 0) {
          return 'AM 12:$minute';
        } else {
          return 'AM ${hour.toString().padLeft(2, '0')}:$minute';
        }
      } else if (hour == 12) {
        return 'PM 12:$minute';
      } else {
        return 'PM ${(hour - 12).toString().padLeft(2, '0')}:$minute';
      }
    } catch (e) {
      return 'AM 09:00'; // 기본값
    }
  }

// 4. AI 플래너 완성 팁 다이얼로그 (새로운 버전)
  void _showAIPlannerCompleteTipsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade300, Colors.pink.shade300],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎯 AI 맞춤 플래너 완성!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('AI가 당신만의 플래너를 생성했어요',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.pink.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.purple.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎯 표시된 일정들은 AI가 당신의 패턴을 분석해서 추천한 맞춤 일정입니다!',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.touch_app,
                title: '✏️ 일정 수정하기',
                description: 'AI 추천 일정도 탭해서 시간이나 내용을 수정할 수 있어요',
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.check_circle,
                title: '✅ 완료 체크하기',
                description: '추천 일정을 완료하면 AI가 더 나은 추천을 제공해요',
                color: Colors.green,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.refresh,
                title: '🔄 재추천받기',
                description: '보라색 버튼을 다시 눌러 추가 추천을 받을 수 있어요',
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.analytics,
                title: '📊 학습 시스템',
                description: '사용 패턴을 분석해서 점점 더 정확한 추천을 제공해요',
                color: Colors.teal,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('알겠어요!', style: TextStyle(color: Colors.purple)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // 추가 추천 받기
              _generateAISchedule();
            },
            icon: Icon(Icons.add, size: 18),
            label: Text('추가 추천'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

// 5. 플래너 뷰에서 AI 추천 일정을 구분해서 표시하는 함수 수정
  Widget _buildTodoTaskCard(Todo_Task task) {
    final start = _parseTimeToDateTime(task.time, task.date);
    final end = _parseTimeToDateTime(task.endTime, task.date);
    final timeRange = (start != null && end != null)
        ? '${DateFormat.Hm().format(start)} - ${DateFormat.Hm().format(end)}'
        : '';

    // 완료 여부에 따른 스타일 조정
    final isCompleted = task.isCompleted;

    // AI 추천 일정인지 확인
    final isAIRecommendation = task.title.startsWith('🎯') ||
        task.description?.contains('AI 맞춤 추천') == true;

    // 현재 날짜와 비교
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
    final diffDays = taskDate.difference(today).inDays;

    String dateStatus = '';
    if (diffDays == 0) {
      dateStatus = 'Today';
    } else if (diffDays == 1) {
      dateStatus = 'Tomorrow';
    } else if (diffDays == -1) {
      dateStatus = 'Yesterday';
    }

    // 제목에서 첫 글자만 대문자로 표시하기 위한 처리
    String taskInitial = task.title.isNotEmpty ? task.title[0].toUpperCase() : '';

    return GestureDetector(
      onTap: () {
        // 플래너 일정 클릭 시 수정 다이얼로그 열기
        _showPlannerTaskEditDialog(task);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          // AI 추천 일정은 특별한 스타일
          color: isAIRecommendation
              ? Colors.purple.shade50
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAIRecommendation
                ? Colors.purple.shade200
                : Colors.grey.shade200,
            width: isAIRecommendation ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isAIRecommendation
                  ? Colors.purple.withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isAIRecommendation ? 6 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 추천 라벨 (AI 추천인 경우만)
            if (isAIRecommendation)
              Container(
                margin: EdgeInsets.only(left: 12, right: 12, top: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.pink.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'AI 맞춤 추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // 상단 부분 (제목 및 상태 표시)
            Padding(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 8,
                  top: isAIRecommendation ? 8 : 12,
                  bottom: 4
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작은 네모박스
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isAIRecommendation
                          ? Colors.purple.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        taskInitial,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAIRecommendation
                              ? Colors.purple.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),

                  // 날짜 및 시간 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목 표시
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? Colors.grey : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 날짜 정보 표시
                        Text(
                          dateStatus.isNotEmpty
                              ? '$dateStatus, $timeRange'
                              : timeRange,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        // AI 추천인 경우 신뢰도 표시
                        if (isAIRecommendation && task.memo != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              task.memo!.split('\n').first, // 신뢰도 부분만
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 체크박스
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        setState(() {
                          _taskDataService.updateTaskStatus(task, value ?? false);
                          updateProgress();

                          // AI 추천 완료 시 특별한 피드백
                          if (isAIRecommendation && value == true) {
                            _recordAIRecommendationCompletion(task);
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      activeColor: isAIRecommendation ? Colors.purple : Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // 하단 부분 (메모와 위치 정보)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI 추천 이유 표시 (AI 추천인 경우)
                  if (isAIRecommendation && task.memo != null && task.memo!.contains('\n'))
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.purple.shade300,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        task.memo!.split('\n').skip(1).join('\n'), // 이유 부분
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.purple.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  // 일반 메모 정보 (AI 추천이 아닌 경우)
                  if (!isAIRecommendation && task.memo != null && task.memo!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.blue.shade300,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        task.memo!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                  // 위치 정보가 있으면 표시
                  if (task.location != null && task.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            task.location!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 마감일이 있으면 표시
                  if (task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MM/dd').format(task.dueDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// 6. AI 추천 완료 시 피드백 기록
  Future<void> _recordAIRecommendationCompletion(Todo_Task task) async {
    try {
      // AI 서버에 완료 기록 전송
      final String serverUrl = 'https://railwavve-production-68d4.up.railway.app/submit_feedback';

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userFeedback': 'task_completed',
          'scheduledTasks': [{
            'taskId': task.id,
            'taskTitle': task.title,
            'scheduledTime': task.time,
            'importance': task.importance,
            'urgency': task.urgency,
            'isCompleted': true,
          }],
          'actualFollowedSchedule': true,
          'userComment': 'AI 추천 작업 완료',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ AI 추천 완료 기록 전송 성공');
        // 완료 축하 메시지
        _showSnackBar('🎉 AI 추천 완료! 더 나은 추천을 위해 학습합니다.');
      }
    } catch (e) {
      print('❌ AI 추천 완료 기록 오류: $e');
      // 로컬에서만 메시지 표시
      _showSnackBar('🎉 AI 추천 완료!');
    }
  }

  // 8. AI 추천 상태를 확인하는 새로운 함수 추가
  Future<Map<String, dynamic>?> _getAIModelStatus() async {
    try {
      final response = await http.get(
        Uri.parse('https://railwavve-production-68d4.up.railway.app/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['status'],
          'model_loaded': data['model_loaded'] ?? false,
          'ai_available': data['ai_available'] ?? false,
          'timestamp': data['timestamp'],
        };
      }
      return null;
    } catch (e) {
      print('AI 모델 상태 확인 실패: $e');
      return null;
    }
  }

  // 플래너 일정 수정 다이얼로그
  void _showPlannerTaskEditDialog(Todo_Task task) {
    final titleController = TextEditingController(text: task.title);
    final memoController = TextEditingController(text: task.memo ?? '');
    final locationController = TextEditingController(text: task.location ?? '');

    TimeOfDay? startTime = task.time != null ? _parseTimeStringToTimeOfDay(task.time!) : null;
    TimeOfDay? endTime = task.endTime != null ? _parseTimeStringToTimeOfDay(task.endTime!) : null;

    DateTime taskDate = task.date;
    DateTime? dueDate = task.dueDate;
    int importanceLevel = task.importance;
    int urgencyLevel = task.urgency;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 다이얼로그 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF5F6368)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              '플래너 일정 수정',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF202124),
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // 폼 영역
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPlannerTextField(
                                titleController,
                                '제목',
                                '제목을 입력하세요 (필수)',
                                prefixIcon: Icon(Icons.title, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 20),

                              _buildPlannerDatePicker(context, taskDate, (pickedDate) {
                                setState(() {
                                  taskDate = pickedDate;
                                });
                              }),
                              const SizedBox(height: 20),

                              // 시간 설정
                              _buildPlannerTimeSelector(context, startTime, endTime, (start, end) {
                                setState(() {
                                  startTime = start;
                                  endTime = end;
                                });
                              }),
                              const SizedBox(height: 20),

                              // 중요도
                              _buildPlannerImportanceSelector(setState, importanceLevel, (level) {
                                importanceLevel = level;
                              }),
                              const SizedBox(height: 20),

                              // 긴급도
                              _buildPlannerUrgencySelector(setState, urgencyLevel, (level) {
                                urgencyLevel = level;
                              }),
                              const SizedBox(height: 20),

                              _buildPlannerTextField(
                                memoController,
                                '메모',
                                '메모를 입력하세요.',
                                maxLines: 3,
                                prefixIcon: Icon(Icons.note, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 20),

                              _buildPlannerTextField(
                                locationController,
                                '위치',
                                '위치를 입력하세요.',
                                prefixIcon: Icon(Icons.location_on, color: Color(0xFF5F6368)),
                              ),
                              const SizedBox(height: 30),

                              // 수정 및 삭제 버튼
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 삭제 버튼
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _showDeleteConfirmDialog(task);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade400,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text('삭제'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // 수정 버튼
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await _updatePlannerTask(
                                            task,
                                            titleController.text,
                                            taskDate,
                                            startTime,
                                            endTime,
                                            importanceLevel,
                                            urgencyLevel,
                                            memoController.text,
                                            locationController.text,
                                            dueDate,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF9575CD),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text('수정'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(Todo_Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('일정 삭제'),
        content: Text('정말로 이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await _deletePlannerTask(task);
              Navigator.pop(context); // 확인 다이얼로그 닫기
              Navigator.pop(context); // 수정 다이얼로그 닫기
            },
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 수정된 _updatePlannerTask 함수 - 원본 데이터도 함께 업데이트
  Future<void> _updatePlannerTask(
      Todo_Task task,
      String title,
      DateTime date,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      int importance,
      int urgency,
      String memo,
      String location,
      DateTime? dueDate,
      ) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    // 시간 포맷팅
    String? formattedStart;
    String? formattedEnd;

    if (startTime != null) {
      formattedStart = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    }

    if (endTime != null) {
      formattedEnd = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    }

    // 태스크 업데이트
    task.title = title;
    task.date = date;
    task.time = formattedStart;
    task.endTime = formattedEnd;
    task.importance = importance;
    task.urgency = urgency;
    task.memo = memo;
    task.location = location;
    task.dueDate = dueDate;
    task.isImportant = importance >= 2;
    task.isUrgent = urgency >= 3;

    try {
      // 1. 플래너 데이터 업데이트
      await _taskDataService.updateTaskInFirestore(task);

      // 2. 원본 투두리스트 데이터도 함께 업데이트
      await _updateOriginalTodoTask(task);

      // 3. 캘린더 이벤트가 있다면 함께 업데이트
      await _updateOriginalCalendarEvent(task);

      // UI 업데이트
      setState(() {
        updateProgress();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정이 수정되었습니다 (원본 데이터 포함)')),
      );
    } catch (e) {
      print('플래너 일정 업데이트 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 수정 중 오류가 발생했습니다')),
      );
    }
  }

// 수정된 _deletePlannerTask 함수 - 원본 데이터도 함께 삭제
  Future<void> _deletePlannerTask(Todo_Task task) async {
    try {
      // 1. 플래너 데이터 삭제
      await _taskDataService.removeTaskFromFirestore(task);

      // 2. 원본 투두리스트 데이터도 함께 삭제
      await _deleteOriginalTodoTask(task);

      // 3. 캘린더 이벤트가 있다면 함께 삭제
      await _deleteOriginalCalendarEvent(task);

      // 로컬 데이터에서 삭제
      final dateKey = _taskDataService.dateToKey(task.date);
      if (_taskDataService.plannerTasksByDate.containsKey(dateKey)) {
        _taskDataService.plannerTasksByDate[dateKey]!.removeWhere((t) => t.id == task.id);
      }

      // UI 업데이트
      setState(() {
        updateProgress();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정이 삭제되었습니다.')),
      );
    } catch (e) {
      print('플래너 일정 삭제 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다')),
      );
    }
  }

// 원본 투두리스트 태스크 업데이트
  Future<void> _updateOriginalTodoTask(Todo_Task plannerTask) async {
    try {
      // AM/PM 형식으로 시간 변환 (함수 시작 부분에서 선언)
      String? formattedStartTime;
      String? formattedEndTime;

      if (plannerTask.time != null) {
        final startTime = _parseTimeStringToTimeOfDay(plannerTask.time!);
        if (startTime != null) {
          formattedStartTime = '${startTime.period == DayPeriod.am ? 'AM' : 'PM'} ${startTime.hourOfPeriod.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        }
      }

      if (plannerTask.endTime != null) {
        final endTime = _parseTimeStringToTimeOfDay(plannerTask.endTime!);
        if (endTime != null) {
          formattedEndTime = '${endTime.period == DayPeriod.am ? 'AM' : 'PM'} ${endTime.hourOfPeriod.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        }
      }

      // 제목으로 원본 투두 태스크 찾기
      final todoQuery = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: userId)
          .where('title', isEqualTo: plannerTask.title)
          .where('date', isEqualTo: plannerTask.date.toIso8601String().split('T')[0])
          .get();

      for (var doc in todoQuery.docs) {

        await doc.reference.update({
          'title': plannerTask.title,
          'date': plannerTask.date.toIso8601String(),
          'time': formattedStartTime,
          'endTime': formattedEndTime,
          'importance': plannerTask.importance,
          'urgency': plannerTask.urgency,
          'memo': plannerTask.memo,
          'location': plannerTask.location,
          'dueDate': plannerTask.dueDate?.toIso8601String(),
          'isImportant': plannerTask.isImportant,
          'isUrgent': plannerTask.isUrgent,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 로컬 투두 데이터도 업데이트
      final dateKey = _taskDataService.dateToKey(plannerTask.date);
      if (_taskDataService.todoTasksByDate.containsKey(dateKey)) {
        for (var localTask in _taskDataService.todoTasksByDate[dateKey]!) {
          if (localTask.title == plannerTask.title &&
              _taskDataService.isSameDate(localTask.date, plannerTask.date)) {
            localTask.title = plannerTask.title;
            localTask.date = plannerTask.date;
            localTask.time = formattedStartTime;
            localTask.endTime = formattedEndTime;
            localTask.importance = plannerTask.importance;
            localTask.urgency = plannerTask.urgency;
            localTask.memo = plannerTask.memo;
            localTask.location = plannerTask.location;
            localTask.dueDate = plannerTask.dueDate;
            localTask.isImportant = plannerTask.isImportant;
            localTask.isUrgent = plannerTask.isUrgent;
            break;
          }
        }
      }

      print('원본 투두 태스크 업데이트 완료: ${plannerTask.title}');
    } catch (e) {
      print('원본 투두 태스크 업데이트 오류: $e');
    }
  }

// 원본 캘린더 이벤트 업데이트
  Future<void> _updateOriginalCalendarEvent(Todo_Task plannerTask) async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .where('title', isEqualTo: plannerTask.title)
          .get();

      for (var doc in eventsQuery.docs) {
        final data = doc.data();
        final eventStartDate = (data['startDate'] as Timestamp).toDate();

        // 같은 날짜의 이벤트인지 확인
        if (_taskDataService.isSameDate(eventStartDate, plannerTask.date)) {
          // 시간 변환
          Map<String, dynamic>? startTimeMap;
          Map<String, dynamic>? endTimeMap;

          if (plannerTask.time != null) {
            final startTime = _parseTimeStringToTimeOfDay(plannerTask.time!);
            if (startTime != null) {
              startTimeMap = {
                'hour': startTime.hour,
                'minute': startTime.minute,
              };
            }
          }

          if (plannerTask.endTime != null) {
            final endTime = _parseTimeStringToTimeOfDay(plannerTask.endTime!);
            if (endTime != null) {
              endTimeMap = {
                'hour': endTime.hour,
                'minute': endTime.minute,
              };
            }
          }

          await doc.reference.update({
            'title': plannerTask.title,
            'startDate': Timestamp.fromDate(plannerTask.date),
            'endDate': Timestamp.fromDate(plannerTask.date),
            'startTime': startTimeMap,
            'endTime': endTimeMap,
            'memo': plannerTask.memo,
            'location': plannerTask.location,
            'description': plannerTask.description,
          });
        }
      }

      print('원본 캘린더 이벤트 업데이트 완료: ${plannerTask.title}');
    } catch (e) {
      print('원본 캘린더 이벤트 업데이트 오류: $e');
    }
  }

// 원본 투두리스트 태스크 삭제
  Future<void> _deleteOriginalTodoTask(Todo_Task plannerTask) async {
    try {
      final todoQuery = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: userId)
          .where('title', isEqualTo: plannerTask.title)
          .where('date', isEqualTo: plannerTask.date.toIso8601String().split('T')[0])
          .get();

      for (var doc in todoQuery.docs) {
        await doc.reference.delete();
      }

      // 로컬 투두 데이터에서도 삭제
      final dateKey = _taskDataService.dateToKey(plannerTask.date);
      if (_taskDataService.todoTasksByDate.containsKey(dateKey)) {
        _taskDataService.todoTasksByDate[dateKey]!.removeWhere((localTask) =>
        localTask.title == plannerTask.title &&
            _taskDataService.isSameDate(localTask.date, plannerTask.date));
      }

      print('원본 투두 태스크 삭제 완료: ${plannerTask.title}');
    } catch (e) {
      print('원본 투두 태스크 삭제 오류: $e');
    }
  }

// 원본 캘린더 이벤트 삭제
  Future<void> _deleteOriginalCalendarEvent(Todo_Task plannerTask) async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .where('title', isEqualTo: plannerTask.title)
          .get();

      for (var doc in eventsQuery.docs) {
        final data = doc.data();
        final eventStartDate = (data['startDate'] as Timestamp).toDate();

        // 같은 날짜의 이벤트인지 확인
        if (_taskDataService.isSameDate(eventStartDate, plannerTask.date)) {
          await doc.reference.delete();
        }
      }

      print('원본 캘린더 이벤트 삭제 완료: ${plannerTask.title}');
    } catch (e) {
      print('원본 캘린더 이벤트 삭제 오류: $e');
    }
  }

// TaskDataService에 추가할 날짜 비교 메서드 (만약 없다면)
  bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // 플래너용 날짜 선택기
  Widget _buildPlannerDatePicker(BuildContext context, DateTime taskDate, Function(DateTime) onDatePicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('날짜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF5F6368))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: taskDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                onDatePicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF5F6368)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

// 플래너용 시간 선택기
  Widget _buildPlannerTimeSelector(
      BuildContext context,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      Function(TimeOfDay?, TimeOfDay?) onTimeChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시간 설정',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPlannerTimePicker(
                context,
                startTime ?? TimeOfDay(hour: 9, minute: 0),
                '시작 시간',
                    (time) => onTimeChanged(time, endTime),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPlannerTimePicker(
                context,
                endTime ?? TimeOfDay(hour: 10, minute: 0),
                '종료 시간',
                    (time) => onTimeChanged(startTime, time),
              ),
            ),
          ],
        ),
      ],
    );
  }

// 개별 시간 선택기
  Widget _buildPlannerTimePicker(
      BuildContext context,
      TimeOfDay selectedTime,
      String label,
      Function(TimeOfDay) onTimePicked,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked != null) {
                onTimePicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Icon(Icons.access_time, size: 16, color: Color(0xFF5F6368)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

// 플래너용 중요도 선택기
  Widget _buildPlannerImportanceSelector(StateSetter setState, int importance, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '중요도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: importance.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) {
                        setState(() {
                          onChanged(value.round());
                        });
                      },
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = importance == level;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        onChanged(level);
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getImportanceColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getImportanceColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getImportanceColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 플래너용 긴급도 선택기
  Widget _buildPlannerUrgencySelector(StateSetter setState, int urgency, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '긴급도',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  Expanded(
                    child: Slider(
                      value: urgency.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: Color(0xFF9575CD),
                      inactiveColor: Colors.grey.shade300,
                      onChanged: (value) {
                        setState(() {
                          onChanged(value.round());
                        });
                      },
                    ),
                  ),
                  const Text('높음', style: TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = urgency == level;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        onChanged(level);
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _getUrgencyColor(level) : Colors.transparent,
                        border: Border.all(
                          color: _getUrgencyColor(level),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getUrgencyColor(level),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

// 중요도 색상 반환 함수
  Color _getImportanceColor(int importance) {
    switch (importance) {
      case 1:
        return Colors.blue.shade300;
      case 2:
        return Colors.green.shade400;
      case 3:
        return Colors.orange.shade400;
      case 4:
        return Colors.red.shade400;
      case 5:
        return Colors.purple.shade500;
      default:
        return Colors.grey.shade400;
    }
  }

// 긴급도 색상 반환 함수
  Color _getUrgencyColor(int urgency) {
    switch (urgency) {
      case 1:
        return Colors.teal.shade300;
      case 2:
        return Colors.cyan.shade400;
      case 3:
        return Colors.amber.shade500;
      case 4:
        return Colors.deepOrange.shade400;
      case 5:
        return Colors.red.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  TimeOfDay? _parseTimeStringToTimeOfDay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;

    try {
      String cleanedTime = timeString.trim().toUpperCase();

      // AM/PM 처리
      bool isAM = true; // 기본값을 AM으로 설정
      if (cleanedTime.contains('AM')) {
        isAM = true;
        cleanedTime = cleanedTime.replaceAll('AM', '').trim();
      } else if (cleanedTime.contains('PM')) {
        isAM = false;
        cleanedTime = cleanedTime.replaceAll('PM', '').trim();
      }

      int hour = 0;
      int minute = 0;

      if (cleanedTime.contains(':')) {
        // "HH:mm" 형식
        final parts = cleanedTime.split(':');
        if (parts.length == 2) {
          hour = int.parse(parts[0].trim());
          minute = int.parse(parts[1].trim());
        }
      } else {
        // "HH" 형식 또는 "09" 같은 형식
        final hourStr = cleanedTime.trim();
        if (hourStr.isNotEmpty) {
          // Leading zero 제거하고 파싱
          hour = int.parse(hourStr);
          minute = 0;
        }
      }

      // 12시간제를 24시간제로 변환
      if (!isAM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print('시간 파싱 오류 해결: $e (입력값: $timeString)');
      return TimeOfDay(hour: 9, minute: 0); // 기본값
    }
  }


  // 플래너용 텍스트필드 위젯
  Widget _buildPlannerTextField(
      TextEditingController controller,
      String label,
      String hint, {
        int maxLines = 1,
        Widget? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
            prefixIcon: prefixIcon,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFDADCE0), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF9575CD), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  DateTime _parseTimeToDateTime(String? timeString, DateTime taskDate) {
    if (timeString == null || timeString.isEmpty) {
      return taskDate;
    }

    try {
      // "AM 09" 또는 "PM 03" 형식 처리
      if (timeString.contains('AM') || timeString.contains('PM')) {
        final isAM = timeString.contains('AM');
        final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

        int hour = 0;
        int minute = 0;

        if (timePart.contains(':')) {
          final parts = timePart.split(':');
          // Leading zero 처리를 위해 trim() 후 파싱
          hour = int.tryParse(parts[0].trim()) ?? 0;
          minute = int.tryParse(parts[1].trim()) ?? 0;
        } else {
          // "AM 09" 형식 - Leading zero 처리
          final hourStr = timePart.trim();
          hour = int.tryParse(hourStr) ?? 0;
          minute = 0;
        }

        // 12시간제를 24시간제로 변환
        if (!isAM && hour < 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        return DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          hour,
          minute,
        );
      }

      // "HH:mm" 형식 처리 (24시간)
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0].trim()) ?? 0;
          final minute = int.tryParse(parts[1].trim()) ?? 0;
          return DateTime(
            taskDate.year,
            taskDate.month,
            taskDate.day,
            hour,
            minute,
          );
        }
      }

      // 숫자만 있는 경우 (예: "09")
      final hourOnly = int.tryParse(timeString.trim());
      if (hourOnly != null) {
        return DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          hourOnly,
          0,
        );
      }

      return taskDate;
    } catch (e) {
      print('시간 파싱 오류 해결됨: $e (입력: $timeString)');
      return taskDate;
    }
  }

// _generateLocalSchedule 함수 수정 (캘린더 일정 제목에서 "(일정)" 제거)
  List<Map<String, dynamic>> _generateLocalSchedule(
      List<Map<String, dynamic>> tasks,
      List<Map<String, dynamic>> calendar) {

    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 1. 캘린더 이벤트 먼저 추가 (고정 일정)
    for (var event in calendar) {
      if (event['startTime'] != null) {
        // 시간 정규화
        final normalizedStartTime = _normalizeTime(event['startTime']);
        final normalizedEndTime = _normalizeTime(event['endTime']);

        int startHour;
        try {
          startHour = int.parse(normalizedStartTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        int endHour;
        if (normalizedEndTime != null) {
          try {
            endHour = int.parse(normalizedEndTime.split(':')[0]);
            endHour = endHour.clamp(0, 23); // 범위 확인
          } catch (e) {
            endHour = startHour + 1; // 기본값
          }
        } else {
          endHour = startHour + 1;
        }

        // 시간이 뒤바뀐 경우 수정
        if (endHour < startHour) {
          endHour = startHour + 1;
        }

        // 시간대 차지 표시
        for (int h = startHour; h <= endHour; h++) {
          occupiedHours.add(h.clamp(0, 23));
        }

        schedule.add({
          'id': 'cal_${schedule.length}',
          'title': event['title'], // "(일정)" 접두사 제거
          'time': normalizedStartTime,
          'endTime': normalizedEndTime ?? '${(startHour + 1).toString().padLeft(2, '0')}:00',
          'priority': 3, // 최우선
          'description': '캘린더 일정',
          'memo': '',
          'location': event['location'] ?? '',
        });
      }
    }

    // 2. 작업 중요도/긴급도 기준 정렬
    tasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore); // 높은 점수가 먼저 오도록
    });

    // 3. 먼저 사용자가 지정한 시간이 있는 작업 추가
    for (var task in tasks) {
      // 사용자가 지정한 시간이 있는지 확인
      final userTime = task['time'];

      if (userTime != null && userTime.toString().isNotEmpty) {
        // 시간 정규화
        final normalizedTime = _normalizeTime(userTime.toString());
        final normalizedEndTime = _normalizeTime(task['endTime']?.toString());

        // 시작 시간의 시간대만 추출
        int startHour;
        try {
          startHour = int.parse(normalizedTime!.split(':')[0]);
          startHour = startHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          startHour = 9; // 기본값
        }

        // 종료 시간 설정
        String endTime;
        if (normalizedEndTime != null && normalizedEndTime.isNotEmpty) {
          endTime = normalizedEndTime;
        } else {
          // 기본 종료 시간은 시작 + 1시간
          endTime = '${((startHour + 1) % 24).toString().padLeft(2, '0')}:00';
        }

        // 시간대 차지 표시
        occupiedHours.add(startHour);

        // 중요도/긴급도에 따른 우선순위 설정
        final importance = task['importance'] ?? 1;
        final urgency = task['urgency'] ?? 1;
        final priority = importance > urgency ? importance : urgency;

        schedule.add({
          'id': 'task_${schedule.length}',
          'title': task['title'],
          'time': normalizedTime,
          'endTime': endTime,
          'priority': priority,
          'description': '중요도: $importance, 긴급도: $urgency',
          'memo': '',
          'location': '',
          'dueDate': task['dueDate'],
        });

        // 이미 처리된 작업은 표시
        task['_processed'] = true;
      }
    }

    // 4. 남은 시간대에 시간이 지정되지 않은 작업 배치
    int startHour = 9; // 오전 9시부터 시작

    for (var task in tasks) {
      // 이미 처리된 작업은 건너뛰기
      if (task['_processed'] == true) continue;

      // 하루 업무 시간 9시-21시로 제한
      if (startHour >= 21) break;

      // 사용 가능한 시간 찾기
      while (occupiedHours.contains(startHour)) {
        startHour++;
        if (startHour >= 21) break;
      }

      if (startHour >= 21) break;

      // 중요도/긴급도에 따른 우선순위 설정
      final importance = task['importance'] ?? 1;
      final urgency = task['urgency'] ?? 1;
      final priority = importance > urgency ? importance : urgency;

      schedule.add({
        'id': 'task_${schedule.length}',
        'title': task['title'],
        'time': '${startHour.toString().padLeft(2, '0')}:00',
        'endTime': '${(startHour + 1).toString().padLeft(2, '0')}:00',
        'priority': priority,
        'description': '중요도: $importance, 긴급도: $urgency',
        'memo': '',
        'location': '',
        'dueDate': task['dueDate'],
      });

      occupiedHours.add(startHour);
      startHour++;
    }

    // 시간순 정렬
    schedule.sort((a, b) {
      if (a['time'] == null) return 1;
      if (b['time'] == null) return -1;
      return a['time'].toString().compareTo(b['time'].toString());
    });

    return schedule;
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _isLoadingAI ? null : _onSmartActionPressed,
      backgroundColor: _getSmartButtonColor(),
      child: _getSmartButtonIcon(),
    );
  }

  void _onSmartActionPressed() {
    if (isPlannerView) {
      final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);

      // 캘린더 이벤트도 확인
      _fetchCalendarAndTodoCount();
      final hasCalendarEvents = _calendarCount > 0;

      if (todoTasks.isEmpty && !hasCalendarEvents) {
        // 투두와 캘린더 모두 없으면 먼저 추가하도록 안내
        _showNoTodoDialog();
      } else if (plannerTasks.isEmpty) {
        // 투두나 캘린더는 있지만 플래너가 비어있으면 플래너 생성
        _generateAIPlanner();
      } else {
        // 플래너에 일정이 있으면 AI 맞춤 추천 선택 다이얼로그 표시
        _showAIRecommendationDialog();
      }
    } else {
      // 투두 뷰에서는 새 할일 추가
      if (todoListScreenState != null) {
        todoListScreenState!.showAddTaskDialog(context);
      }
    }
  }

  void _showNoTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline, color: Colors.orange.shade600, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              '일정이 필요해요',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 플래너를 생성하려면 먼저 할 일이나 캘린더 일정을 추가해주세요.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '다음 중 하나를 선택하세요:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: 4),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // 투두 뷰로 전환
                            setState(() {
                              isPlannerView = false;
                            });
                            // 투두 추가 다이얼로그 열기
                            Future.delayed(Duration(milliseconds: 300), () {
                              if (todoListScreenState != null) {
                                todoListScreenState!.showAddTaskDialog(context);
                              }
                            });
                          },
                          icon: Icon(Icons.add_task, size: 18),
                          label: Text('할 일 추가'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade200,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left: 4),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showSnackBar('캘린더 앱에서 일정을 추가한 후 다시 시도해주세요.');
                          },
                          icon: Icon(Icons.calendar_today, size: 18),
                          label: Text('캘린더 확인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade200,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.grey.shade100,
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 빠른 투두 추가 다이얼로그
  void _showQuickTodoDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flash_on, color: Colors.green.shade600, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              '빠른 할 일 추가',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: '할 일을 입력하세요',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  autofocus: true,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 예시: 영어 공부, 운동하기, 쇼핑하기, 보고서 작성',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        // 빠른 투두 생성
                        final quickTodo = Todo_Task(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: userId,
                          title: titleController.text.trim(),
                          date: selectedDate,
                          importance: 3, // 기본 중요도
                          urgency: 3,    // 기본 긴급도
                          isImportant: false,
                          isUrgent: false,
                          isCompleted: false,
                          color: null,
                          dueDate: null,
                          notificationId: null,
                          reminderMinutesBefore: null,
                          isRepeating: false,
                          repeatOption: null,
                          repeatDays: null,
                          repeatCustomDays: null,
                        );

                        // 투두 추가
                        _taskDataService.addTodoTask(quickTodo);

                        Navigator.pop(context);

                        // 잠시 후 AI 스케줄 생성
                        Future.delayed(Duration(milliseconds: 500), () {
                          _generateAISchedule();
                        });

                        _showSnackBar('할 일이 추가되었습니다! AI 스케줄을 생성합니다.');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade200,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '추가하고 AI 생성',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


// 태스크 분석 함수
  Map<String, bool> _analyzeTasksForRecommendations(List<Todo_Task> tasks) {
    final analysis = {
      'hasTravel': false,
      'hasPacking': false,
      'hasMeeting': false,
      'hasExercise': false,
      'hasStudy': false,
    };

    final travelKeywords = ['여행', 'travel', '항공', 'flight', '비행기', '호텔', 'hotel'];
    final packingKeywords = ['짐', 'pack', '가방', '준비'];
    final meetingKeywords = ['회의', 'meeting', '미팅', '발표', 'presentation'];
    final exerciseKeywords = ['운동', 'exercise', '헬스', 'gym', '조깅', 'running'];
    final studyKeywords = ['공부', 'study', '학습', '수업', 'class', '과제'];

    for (var task in tasks) {
      final title = task.title.toLowerCase();
      final description = (task.description ?? '').toLowerCase();
      final combined = '$title $description';

      if (_containsAnyKeyword(combined, travelKeywords)) {
        analysis['hasTravel'] = true;
      }
      if (_containsAnyKeyword(combined, packingKeywords)) {
        analysis['hasPacking'] = true;
      }
      if (_containsAnyKeyword(combined, meetingKeywords)) {
        analysis['hasMeeting'] = true;
      }
      if (_containsAnyKeyword(combined, exerciseKeywords)) {
        analysis['hasExercise'] = true;
      }
      if (_containsAnyKeyword(combined, studyKeywords)) {
        analysis['hasStudy'] = true;
      }
    }

    return analysis;
  }

// 키워드 포함 여부 확인
  bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }



  // 사용자 인사이트 가져오기 함수 추가
  Future<Map<String, dynamic>?> getUserInsights() async {
    try {
      final String serverUrl = 'https://railwavve-production-68d4.up.railway.app/user_insights/$userId';

      final response = await http.get(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['insights'];
        }
      }
      return null;
    } catch (e) {
      print('인사이트 가져오기 실패: $e');
      return null;
    }
  }


// 버튼 색상 결정
  Color _getSmartButtonColor() {
    if (_isLoadingAI) return Colors.grey;

    if (isPlannerView) {
      final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      if (todoTasks.isNotEmpty) {
        return Color(0xFFB39DDB); // AI 추천 가능
      }
    }

    return const Color(0xFFB39DDB); // 기본 색상
  }

  Widget _getSmartButtonIcon() {
    if (_isLoadingAI) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    if (isPlannerView) {
      final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);

      _fetchCalendarAndTodoCount();
      final hasCalendarEvents = _calendarCount > 0;

      if ((todoTasks.isNotEmpty || hasCalendarEvents) && plannerTasks.isEmpty) {
        return Icon(Icons.auto_awesome, color: Colors.white); // 플래너 생성 아이콘
      } else if (plannerTasks.isNotEmpty) {
        return Icon(Icons.psychology, color: Colors.white); // AI 맞춤 추천 아이콘
      }
    }

    return Icon(Icons.add, color: Colors.white, size: 30); // 기본 + 아이콘
  }

// 버튼 텍스트 결정 (툴팁용)
  String _getSmartButtonText() {
    if (_isLoadingAI) return '생성 중...';

    if (isPlannerView) {
      final todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);

      if (todoTasks.isNotEmpty && plannerTasks.isEmpty) {
        return 'AI 추천';
      } else if (plannerTasks.isNotEmpty) {
        return '재생성';
      } else {
        return '생성';
      }
    }

    return '할일 추가';
  }

  void _showAIRecommendationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology, color: Colors.purple.shade600, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              '스마트 AI 추천',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '현재 플래너를 분석해서 연관된 맞춤 추천을 생성할까요?',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ),
        actions: [
          Container(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: 4),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _generateAISchedule();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade200,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text('AI 맞춤 추천'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left: 4),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showPlannerGeneratingDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade200,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Text('플래너 재생성'),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.grey.shade100,
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showPlannerGeneratingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D8CFF)),
                ),
                const SizedBox(height: 20),
                const Text(
                  '플래너 생성 중...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '투두리스트와 캘린더 일정을 분석하여\n최적의 플래너를 생성하고 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // AI planner generation simulation
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop();
      _generateAIPlanner();
    });
  }

  String convertTimeIfNeeded(dynamic timeValue) {
    if (timeValue == null) return '';

    String timeStr = timeValue.toString();

    // 이미 :가 있으면 그대로 반환
    if (timeStr.contains(':')) {
      return timeStr;
    }

    // :가 없으면 변환
    double time = double.tryParse(timeStr) ?? 0.0;
    int hours = time.floor();
    int minutes = ((time - hours) * 100).round();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _generateAIPlanner() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('=== AI 플래너 생성 시작 ===');

      // 1. Todo 태스크 가져오기
      final List<Todo_Task> todoTasks = _taskDataService.getTodoTasksForDate(selectedDate);
      print('투두 태스크 수: ${todoTasks.length}');

      // 2. 캘린더 이벤트 가져오기
      List<Map<String, dynamic>> calendarEvents = await _loadCalendarEventsForDate(selectedDate);
      print('로드된 캘린더 이벤트 수: ${calendarEvents.length}');

      // 3. 투두와 캘린더 모두 없으면 안내 메시지
      if (todoTasks.isEmpty && calendarEvents.isEmpty) {
        setState(() {
          isLoading = false;
        });
        _showSnackBar('투두리스트나 캘린더 일정을 먼저 추가해주세요.');
        return;
      }

      // 4. 기존 플래너 데이터 초기화
      final dateKey = _taskDataService.dateToKey(selectedDate);
      _taskDataService.plannerTasksByDate[dateKey] = [];

      print('=== 1단계: 기본 플래너 생성 ===');

      // 5. 캘린더 이벤트를 플래너에 먼저 추가 (고정 일정)
      int addedCalendarEvents = 0;
      for (var event in calendarEvents) {
        try {
          final calendarTask = Todo_Task(
            id: event['id'] ?? 'cal_${DateTime.now().millisecondsSinceEpoch}_${addedCalendarEvents}',
            userId: userId,
            title: '${event['title']}',
            date: selectedDate,
            time: event['startTime'],
            endTime: event['endTime'],
            importance: 5,
            urgency: 5,
            isImportant: true,
            isUrgent: true,
            description: '캘린더 일정: ${event['description'] ?? ''}',
            memo: event['memo'] ?? '',
            location: event['location'] ?? '',
            isCompleted: false,
            color: null,
            dueDate: null,
            notificationId: null,
            reminderMinutesBefore: null,
            isRepeating: false,
            repeatOption: null,
            repeatDays: null,
            repeatCustomDays: null,
          );

          _taskDataService.addPlannerTask(calendarTask);
          await _taskDataService.savePlannerTaskToFirestore(calendarTask);
          addedCalendarEvents++;
          print('캘린더 일정 플래너에 추가: ${event['title']} at ${event['startTime']}');
        } catch (e) {
          print('캘린더 일정 추가 오류: $e');
          continue;
        }
      }

      // 6. Todo 태스크를 플래너에 추가
      int addedTodoTasks = 0;
      for (var task in todoTasks) {
        try {
          String? taskTime = task.time;
          String? taskEndTime = task.endTime;

          if (taskTime == null || taskTime.isEmpty) {
            int defaultHour = 9 + addedTodoTasks;
            if (defaultHour > 21) defaultHour = 21;
            taskTime = '${defaultHour.toString().padLeft(2, '0')}:00';
            taskEndTime = '${(defaultHour + 1).toString().padLeft(2, '0')}:00';
          }

          final todoTask = Todo_Task(
            id: task.id,
            userId: userId,
            title: task.title,
            date: selectedDate,
            time: taskTime,
            endTime: taskEndTime,
            importance: task.importance,
            urgency: task.urgency,
            isImportant: task.isImportant,
            isUrgent: task.isUrgent,
            description: task.description,
            memo: task.memo,
            location: task.location,
            isCompleted: false,
            color: null,
            dueDate: task.dueDate,
            notificationId: null,
            reminderMinutesBefore: null,
            isRepeating: task.isRepeating,
            repeatOption: task.repeatOption,
            repeatDays: task.repeatDays,
            repeatCustomDays: task.repeatCustomDays,
          );

          _taskDataService.addPlannerTask(todoTask);
          await _taskDataService.savePlannerTaskToFirestore(todoTask);
          addedTodoTasks++;
          print('투두 일정 추가: ${task.title} at ${taskTime}');
        } catch (e) {
          print('투두 일정 추가 오류: $e');
          continue;
        }
      }

      // 7. UI 업데이트 (기본 플래너 표시)
      setState(() {
        updateProgress();
        isPlannerView = true;
        isLoading = false;
      });

      // 성공 메시지
      String message = '🎉 플래너 생성 완료!';
      if (addedCalendarEvents > 0) {
        message += ' 캘린더 ${addedCalendarEvents}개';
      }
      if (addedTodoTasks > 0) {
        if (addedCalendarEvents > 0) message += '와 ';
        message += '투두 ${addedTodoTasks}개';
      }
      message += '가 추가되었습니다.';

      _showSnackBar(message);

      // 플래너 생성 완료 후 AI 추천 여부 다이얼로그 표시
      Future.delayed(Duration(milliseconds: 1500), () {
        if (mounted) {
          _showAIRecommendationAfterPlannerDialog();
        }
      });

    } catch (e) {
      print('AI 플래너 생성 오류: $e');
      setState(() {
        isLoading = false;
      });
      _showSnackBar('플래너 생성 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  void _showAIRecommendationAfterPlannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade300, Colors.pink.shade300],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 플래너 완성!',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AI 맞춤 추천을 받아보시겠어요?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI가 현재 플래너를 분석해서 연관된 맞춤 추천을 제공해드릴 수 있어요.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.purple.shade600, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 여행, 운동, 회의 등 관련 준비사항을 추천해드려요!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text(
                        '나중에',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // AI 추천 바로 실행
                      _generateAISchedule();
                    },
                    icon: Icon(Icons.psychology, size: 18),
                    label: Text('AI 추천받기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade300,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 3. 맥락적 추천 생성 함수 (새로 추가)
  Future<List<TaskRecommendation>> _generateContextualRecommendations(List<Todo_Task> existingTasks) async {
    final recommendations = <TaskRecommendation>[];
    final occupiedHours = <int>{};

    // 기존 일정 시간 수집
    for (var task in existingTasks) {
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          occupiedHours.add(hour);
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }

    print('점유된 시간대: $occupiedHours');

    // 일정 분석
    final analysis = _analyzeExistingSchedule(existingTasks);
    print('일정 분석 결과: $analysis');

    // 맥락적 추천 생성
    final contextualSuggestions = _generateContextualSuggestions(analysis, existingTasks);

    // 최대 5개까지 추천 생성
    for (int i = 0; i < contextualSuggestions.length && recommendations.length < 5; i++) {
      final suggestion = contextualSuggestions[i];
      final preferredHours = suggestion['preferredHours'] as List<int>;

      // 최적 시간 찾기
      String optimalTime = '18:00'; // 기본값
      for (int hour in preferredHours) {
        if (!occupiedHours.contains(hour) && hour >= 6 && hour <= 22) {
          optimalTime = '${hour.toString().padLeft(2, '0')}:00';
          occupiedHours.add(hour); // 시간 점유 표시
          break;
        }
      }

      recommendations.add(TaskRecommendation(
        taskId: 'contextual_${i}',
        taskTitle: suggestion['title'] as String,
        recommendedTime: optimalTime,
        confidence: suggestion['confidence'] as double,
        reason: suggestion['reason'] as String,
      ));
    }

    print('맥락적 추천 생성 완료: ${recommendations.length}개');
    return recommendations;
  }

// 4. 기존 일정 분석 함수 (새로 추가)
  Map<String, dynamic> _analyzeExistingSchedule(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'totalTasks': tasks.length,
      'categories': <String, int>{},
      'hasTravel': false,
      'hasMeeting': false,
      'hasExercise': false,
      'hasStudy': false,
      'hasMedical': false,
      'hasShopping': false,
      'workloadLevel': 'medium',
      'timeGaps': <String>[],
      'busyPeriods': <String>[],
      'dominantCategories': <String>[],
    };

    if (tasks.isEmpty) return analysis;

    // 카테고리 분석
    final categoryCount = <String, int>{};
    final hourDistribution = <int, int>{};

    for (var task in tasks) {
      final title = task.title.toLowerCase();
      final description = (task.description ?? '').toLowerCase();
      final combined = '$title $description';

      // 카테고리 분류
      String category = _getTaskType(task.title);
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;

      // 특정 키워드 분석
      if (_containsKeywords(combined, ['여행', 'travel', '항공', '출국', '비행기'])) {
        analysis['hasTravel'] = true;
      }
      if (_containsKeywords(combined, ['회의', 'meeting', '미팅', '발표'])) {
        analysis['hasMeeting'] = true;
      }
      if (_containsKeywords(combined, ['운동', 'exercise', '헬스', '조깅'])) {
        analysis['hasExercise'] = true;
      }
      if (_containsKeywords(combined, ['공부', 'study', '학습', '수업'])) {
        analysis['hasStudy'] = true;
      }
      if (_containsKeywords(combined, ['병원', '의료', '검진', '치료'])) {
        analysis['hasMedical'] = true;
      }
      if (_containsKeywords(combined, ['쇼핑', 'shopping', '마트', '구매'])) {
        analysis['hasShopping'] = true;
      }

      // 시간 분포 분석
      if (task.time != null) {
        try {
          final hour = _parseTimeToHour(task.time!);
          hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
        } catch (e) {
          // 파싱 실패 시 무시
        }
      }
    }

    // 지배적인 카테고리 찾기
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    analysis['dominantCategories'] = sortedCategories.take(3).map((e) => e.key).toList();
    analysis['categories'] = categoryCount;

    // 작업량 레벨 계산
    if (tasks.length >= 8) {
      analysis['workloadLevel'] = 'high';
    } else if (tasks.length <= 3) {
      analysis['workloadLevel'] = 'low';
    } else {
      analysis['workloadLevel'] = 'medium';
    }

    // 시간 공백 찾기
    final timeGaps = <String>[];
    for (int hour = 9; hour <= 18; hour++) {
      if (!hourDistribution.containsKey(hour)) {
        timeGaps.add('${hour.toString().padLeft(2, '0')}:00');
      }
    }
    analysis['timeGaps'] = timeGaps;

    return analysis;
  }

// 5. 맥락적 제안 생성 함수 (새로 추가)
  List<Map<String, dynamic>> _generateContextualSuggestions(
      Map<String, dynamic> analysis,
      List<Todo_Task> existingTasks
      ) {
    final suggestions = <Map<String, dynamic>>[];

    // 여행 관련 추천
    if (analysis['hasTravel'] == true) {
      suggestions.addAll([
        {
          'title': '여권 및 비자 서류 확인',
          'confidence': 0.95,
          'reason': '여행 일정 관련 필수 서류 사전 확인',
          'preferredHours': [8, 9, 10, 19, 20],
        },
        {
          'title': '항공편 체크인 및 좌석 선택',
          'confidence': 0.9,
          'reason': '원활한 출국을 위한 사전 체크인',
          'preferredHours': [8, 9, 10],
        },
        {
          'title': '여행용 가방 및 필수품 체크리스트 작성',
          'confidence': 0.85,
          'reason': '체계적인 짐 준비를 위한 리스트',
          'preferredHours': [15, 16, 17, 18],
        },
      ]);
    }

    // 회의/업무 관련 추천
    if (analysis['hasMeeting'] == true) {
      suggestions.addAll([
        {
          'title': '회의 자료 및 발표 준비',
          'confidence': 0.9,
          'reason': '효과적인 회의를 위한 사전 준비',
          'preferredHours': [8, 9, 17, 18],
        },
        {
          'title': '참석자 명단 및 아젠다 확인',
          'confidence': 0.85,
          'reason': '회의 효율성 향상을 위한 사전 점검',
          'preferredHours': [8, 9, 18],
        },
      ]);
    }

    // 운동 관련 추천
    if (analysis['hasExercise'] == true) {
      suggestions.addAll([
        {
          'title': '운동복 및 운동화 준비',
          'confidence': 0.85,
          'reason': '효과적인 운동을 위한 장비 준비',
          'preferredHours': [7, 8, 17, 18, 19],
        },
        {
          'title': '운동 전 워밍업 및 스트레칭',
          'confidence': 0.8,
          'reason': '부상 방지를 위한 사전 준비운동',
          'preferredHours': [7, 8, 18, 19],
        },
      ]);
    }

    // 공부/학습 관련 추천
    if (analysis['hasStudy'] == true) {
      suggestions.addAll([
        {
          'title': '교재 및 필기도구 준비',
          'confidence': 0.8,
          'reason': '효율적인 학습을 위한 도구 준비',
          'preferredHours': [9, 10, 14, 15],
        },
        {
          'title': '조용한 학습 환경 조성',
          'confidence': 0.75,
          'reason': '집중력 향상을 위한 환경 준비',
          'preferredHours': [8, 9, 19, 20],
        },
      ]);
    }

    // 의료 관련 추천
    if (analysis['hasMedical'] == true) {
      suggestions.addAll([
        {
          'title': '건강보험증 및 신분증 준비',
          'confidence': 0.9,
          'reason': '병원 방문을 위한 필수 서류 준비',
          'preferredHours': [8, 9, 19, 20],
        },
        {
          'title': '증상 및 문의사항 정리',
          'confidence': 0.85,
          'reason': '효과적인 진료를 위한 사전 준비',
          'preferredHours': [19, 20, 21],
        },
      ]);
    }

    // 쇼핑 관련 추천
    if (analysis['hasShopping'] == true) {
      suggestions.addAll([
        {
          'title': '쇼핑 리스트 작성',
          'confidence': 0.85,
          'reason': '효율적인 쇼핑을 위한 리스트 준비',
          'preferredHours': [8, 9, 19, 20],
        },
        {
          'title': '예산 계획 및 할인 정보 확인',
          'confidence': 0.8,
          'reason': '경제적인 쇼핑을 위한 사전 조사',
          'preferredHours': [19, 20, 21],
        },
      ]);
    }

    // 작업량에 따른 추천
    final workloadLevel = analysis['workloadLevel'] as String;
    if (workloadLevel == 'high') {
      suggestions.addAll([
        {
          'title': '하루 일정 우선순위 재정리',
          'confidence': 0.8,
          'reason': '과도한 일정으로 인한 스트레스 관리',
          'preferredHours': [8, 12, 18],
        },
        {
          'title': '중간 휴식 및 에너지 충전',
          'confidence': 0.9,
          'reason': '바쁜 일정 중 필수 휴식시간',
          'preferredHours': [12, 13, 15, 17],
        },
      ]);
    } else if (workloadLevel == 'low') {
      suggestions.addAll([
        {
          'title': '추가 자기계발 시간',
          'confidence': 0.8,
          'reason': '여유로운 일정을 활용한 성장 기회',
          'preferredHours': [14, 15, 16, 19, 20],
        },
        {
          'title': '미뤄둔 일 정리',
          'confidence': 0.75,
          'reason': '여유 시간을 활용한 밀린 업무 처리',
          'preferredHours': [10, 11, 15, 16],
        },
      ]);
    }

    // 일반적인 생활 관리 추천 (항상 포함)
    suggestions.addAll([
      {
        'title': '내일 일정 미리 확인',
        'confidence': 0.7,
        'reason': '효율적인 하루 마무리 및 내일 준비',
        'preferredHours': [20, 21, 22],
      },
      {
        'title': '오늘 하루 돌아보기',
        'confidence': 0.65,
        'reason': '성찰과 개선을 위한 하루 정리',
        'preferredHours': [21, 22],
      },
    ]);

    // 신뢰도 순으로 정렬
    suggestions.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));

    return suggestions;
  }


  // 누락된 함수들 추가
  String _extractTaskCategory(String title, String? description) {
    return _getTaskType(title);
  }

  String _inferCategoryFromTitle(String title) {
    return _getTaskType(title);
  }

  String _extractContextualKeywords(String title, String? description) {
    final text = '$title ${description ?? ''}'.toLowerCase();
    final keywords = <String>[];

    if (text.contains('여행') || text.contains('travel')) keywords.add('travel');
    if (text.contains('회의') || text.contains('meeting')) keywords.add('meeting');
    if (text.contains('운동') || text.contains('exercise')) keywords.add('exercise');
    if (text.contains('공부') || text.contains('study')) keywords.add('study');

    return keywords.join(', ');
  }

  double _calculateComplexityScore(Todo_Task task) {
    double complexity = 0.0;
    complexity += (task.importance + task.urgency) / 10.0;
    complexity += min(task.title.length / 50.0, 0.3);
    if (task.description != null && task.description!.isNotEmpty) {
      complexity += 0.2;
    }
    return complexity.clamp(0.0, 1.0);
  }

  Future<List<String>> _identifyShortTermGoals(List<Todo_Task> tasks) async {
    return ['단기목표1', '단기목표2'];
  }

  Future<List<String>> _identifyLongTermObjectives() async {
    return ['장기목표1', '장기목표2'];
  }

  List<String> _identifyPriorityAreas(List<Todo_Task> tasks) {
    return ['우선순위1', '우선순위2'];
  }

  List<String> _identifyImprovementAreas() {
    return ['개선영역1', '개선영역2'];
  }

  Map<String, dynamic> _assessWorkLifeBalance(List<Todo_Task> tasks) {
    return {'workRatio': 0.6, 'lifeRatio': 0.4};
  }

  Future<Map<String, dynamic>> _getWeatherContext() async {
    return {'weather': 'sunny', 'temperature': 20};
  }

  List<Todo_Task> _getUpcomingDeadlines(List<Todo_Task> tasks) {
    return tasks.where((task) => task.dueDate != null).toList();
  }

  Future<double> _calculateRecentCompletionTrend() async {
    return 0.8;
  }

  String _estimateCurrentMood(List<Todo_Task> tasks) {
    return 'positive';
  }

  double _estimateMotivationLevel(List<Todo_Task> tasks) {
    return 0.7;
  }

  Future<Map<String, dynamic>> _analyzeTaskSequencePatterns() async {
    return {'patterns': []};
  }

  Future<Map<String, dynamic>> _analyzeContextualSuccessFactors() async {
    return {'factors': []};
  }

  Future<Map<String, dynamic>> _analyzeCognitiveLoadPatterns() async {
    return {'patterns': []};
  }

  Future<Map<String, dynamic>> _analyzeFlowStateIndicators() async {
    return {'indicators': []};
  }

  Future<Map<String, dynamic>> _analyzeProcrastinationPatterns() async {
    return {'patterns': []};
  }

  Future<List<int>> _identifyPeakPerformanceWindows() async {
    return [9, 10, 14, 15];
  }

  double _calculateDataQualityScore() {
    return 0.8;
  }

  double _calculateAnalysisConfidence() {
    return 0.75;
  }

  double _calculatePersonalizationWeight() {
    return 0.7;
  }

  int _calculateDayLength(DateTime date) {
    return 12; // 기본값 12시간
  }

  double _getSeasonalMoodFactor(String season) {
    switch (season) {
      case 'spring': return 0.8;
      case 'summer': return 0.9;
      case 'autumn': return 0.7;
      case 'winter': return 0.6;
      default: return 0.7;
    }
  }

  Future<Map<String, dynamic>> _collectUserBehaviorData() async {
    return {'behaviors': []};
  }

  Future<void> _updateUserLearningFromAI(List<TaskRecommendation> recommendations) async {
    // AI 학습 업데이트 로직
  }

  Future<void> _recordAIRecommendationSuccess(int count) async {
    print('AI 추천 성공 기록: $count개');
  }

  Future<void> _syncAILearningData(Map<String, dynamic> data) async {
    // 학습 데이터 동기화
  }

  Future<void> _recordAIRecommendationMetrics(
      List<TaskRecommendation> recommendations,
      String method,
      Map<String, dynamic> metrics
      ) async {
    // 메트릭 기록
  }


  Future<List<TaskRecommendation>> _generateEnhancedAIRecommendations({
    required List<Todo_Task> existingTasks,
    required Map<String, dynamic> userContext,
  }) async {
    try {
      const String endpoint = '/ai_recommendation';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('🤖 AI 모델 기반 맞춤 추천 시작');

      // 사용자의 완료 패턴 분석
      final completionHistory = await _analyzeUserCompletionHistory();

      // 시간대별 선호도 분석
      final timePreferences = _analyzeTimePreferences(existingTasks);

      // 기존 일정 상세 분석
      final scheduleAnalysis = _analyzeScheduleContext(existingTasks);

      // 향상된 사용자 컨텍스트 구성
      final enhancedUserContext = {
        ...userContext,
        'completionHistory': completionHistory,
        'timePreferences': timePreferences,
        'scheduleAnalysis': scheduleAnalysis,
        'learningData': await _getUserLearningData(),
      };

      // 기존 태스크를 AI 분석용으로 변환
      final analyzedTasks = existingTasks.map((task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description ?? '',
        'time': task.time,
        'endTime': task.endTime,
        'importance': task.importance,
        'urgency': task.urgency,
        'category': _getTaskType(task.title),
        'location': task.location ?? '',
        'memo': task.memo ?? '',
        'isCompleted': task.isCompleted,
        'date': task.date.toIso8601String(),

        // AI 분석을 위한 추가 정보
        'estimatedDuration': _calculateTaskDuration(task),
        'focusRequirement': _calculateFocusRequirement(task),
        'timeFlexibility': _calculateTimeFlexibility(task),
        'contextualKeywords': _extractContextualKeywords(task.title, task.description),
        'userHistoryMatch': _findSimilarTasksInHistory(task),
      }).toList();

      final requestData = {
        'userId': userContext['userId'],
        'existingTasks': analyzedTasks,
        'userContext': enhancedUserContext,
        'maxRecommendations': 5,
        'analysisType': 'deep_contextual',
        'enableLearning': true,
      };

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Analysis-Type': 'ai_model_based',
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['recommendations'] != null) {
          final recommendations = responseData['recommendations'] as List;
          final aiModelUsed = responseData['ai_model_used'] ?? false;
          final learningUpdated = responseData['learning_updated'] ?? false;

          print('✅ AI 모델 추천 성공: ${recommendations.length}개');
          print('📊 AI 모델 사용: $aiModelUsed');
          print('🧠 학습 업데이트: $learningUpdated');

          // 추천을 TaskRecommendation 객체로 변환
          final result = recommendations.map((rec) => TaskRecommendation(
            taskId: rec['taskId']?.toString() ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
            taskTitle: rec['taskTitle']?.toString() ?? '맞춤 추천',
            recommendedTime: rec['recommendedTime']?.toString() ?? '09:00',
            confidence: (rec['confidence'] as num?)?.toDouble() ?? 0.7,
            reason: rec['reason']?.toString() ?? 'AI 모델 분석 기반 맞춤 추천',
          )).toList();

          // 로컬에서 학습 데이터 업데이트
          if (learningUpdated) {
            await _updateLocalLearningData(responseData['learningData']);
          }

          return result;
        }
      }

      throw Exception('AI 서버 응답 오류');

    } catch (e) {
      print('❌ AI 모델 추천 실패: $e');
      // 폴백으로 기존 로직 사용
      return await _generateContextualRecommendations(existingTasks);
    }
  }

// 4. 일정 컨텍스트 분석 함수 추가
  Map<String, dynamic> _analyzeScheduleContext(List<Todo_Task> tasks) {
    final analysis = <String, dynamic>{
      'taskDensity': 'medium',
      'categoryDistribution': <String, int>{},
      'timeGaps': <String>[],
      'stressLevel': 'medium',
      'focusRequirements': <String, double>{},
      'contextualThemes': <String>[],
    };

    if (tasks.isEmpty) return analysis;

    // 작업 밀도 계산
    final totalHours = tasks.length * 1.5; // 평균 1.5시간 가정
    if (totalHours > 12) {
      analysis['taskDensity'] = 'high';
    } else if (totalHours < 6) {
      analysis['taskDensity'] = 'low';
    }

    // 카테고리 분포
    final categories = <String, int>{};
    final themes = <String>[];

    for (var task in tasks) {
      final category = _getTaskType(task.title);
      categories[category] = (categories[category] ?? 0) + 1;

      // 컨텍스트 테마 추출
      final title = task.title.toLowerCase();
      if (title.contains('여행') || title.contains('travel')) themes.add('여행');
      if (title.contains('회의') || title.contains('meeting')) themes.add('업무');
      if (title.contains('운동') || title.contains('exercise')) themes.add('건강');
      if (title.contains('공부') || title.contains('study')) themes.add('학습');
    }

    analysis['categoryDistribution'] = categories;
    analysis['contextualThemes'] = themes.toSet().toList();

    // 스트레스 레벨 계산
    final highPriorityTasks = tasks.where((t) => t.importance >= 4 || t.urgency >= 4).length;
    final stressRatio = highPriorityTasks / tasks.length;

    if (stressRatio > 0.6) {
      analysis['stressLevel'] = 'high';
    } else if (stressRatio < 0.3) {
      analysis['stressLevel'] = 'low';
    }

    print('📋 일정 컨텍스트: ${analysis['taskDensity']} 밀도, ${themes.length}개 테마');
    return analysis;
  }

// 5. 사용자 학습 데이터 관리
  Future<Map<String, dynamic>> _getUserLearningData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final learningDataJson = prefs.getString('user_learning_data_$userId');

      if (learningDataJson != null) {
        return jsonDecode(learningDataJson);
      }

      return {
        'completionPatterns': <String, dynamic>{},
        'preferenceWeights': <String, double>{},
        'feedbackHistory': <String, dynamic>{},
        'adaptationLevel': 0.0,
      };
    } catch (e) {
      print('학습 데이터 로드 오류: $e');
      return {};
    }
  }


  Future<void> _updateLocalLearningData(Map<String, dynamic> newLearningData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final learningDataJson = jsonEncode(newLearningData);
      await prefs.setString('user_learning_data_$userId', learningDataJson);

      print('🧠 로컬 학습 데이터 업데이트 완료');
    } catch (e) {
      print('학습 데이터 저장 오류: $e');
    }
  }

// 6. 키워드 포함 여부 확인 헬퍼 함수
  bool _containsKeywords(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword.toLowerCase()));
  }

  void _showPlannerCompleteTipsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade200, Colors.orange.shade200],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎉 AI 플래너 완성!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  Text('이제 무엇을 할 수 있는지 알려드릴게요',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlannerTipItem(
                icon: Icons.psychology,
                title: '🧠 AI 맞춤 추천받기',
                description: '화면 아래 보라색 버튼을 눌러 더 스마트한 연관 추천을 받아보세요',
                color: Colors.pink.shade300,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.touch_app,
                title: '✏️ 일정 수정하기',
                description: '시간대를 탭하면 언제든지 일정을 수정할 수 있어요',
                color: Colors.blue.shade300,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.check_circle,
                title: '✅ 완료 체크하기',
                description: '할 일을 완료하면 체크박스를 눌러주세요',
                color: Colors.green.shade300,
              ),
              SizedBox(height: 16),
              _buildPlannerTipItem(
                icon: Icons.analytics,
                title: '📊 진행률 확인하기',
                description: '상단에서 오늘의 진행률을 실시간으로 확인할 수 있어요',
                color: Colors.orange.shade300,
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.cyan.shade50, Colors.teal.shade50],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyan.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lightbulb, color: Colors.cyan.shade600, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '💡 AI는 당신의 캘린더와 투두리스트를 분석해서 연관된 작업들을 추천해드려요!',
                        style: TextStyle(
                          color: Colors.cyan.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text('나중에',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // AI 추천 바로 실행
                      _generateAISchedule();
                    },
                    icon: Icon(Icons.psychology, size: 18),
                    label: Text('AI 추천받기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade200,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerTipItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadCalendarEventsForDate(DateTime date) async {
    List<Map<String, dynamic>> calendarEvents = [];

    try {
      print('=== 캘린더 이벤트 로드 디버깅 ===');
      print('검색 날짜: ${date.year}-${date.month}-${date.day}');
      print('사용자 ID: $userId');

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: userId)
          .get();

      print('총 이벤트 문서 수: ${eventsSnapshot.docs.length}');

      for (var doc in eventsSnapshot.docs) {
        try {
          final data = doc.data();
          print('--- 문서 ID: ${doc.id} ---');

          // startDate 필드 처리
          dynamic rawStartDate = data['startDate'];
          print('rawStartDate 타입: ${rawStartDate.runtimeType}');
          print('rawStartDate 값: $rawStartDate');

          DateTime startDate;

          if (rawStartDate is Timestamp) {
            startDate = rawStartDate.toDate();
            print('Timestamp를 DateTime으로 변환: $startDate');
          } else if (rawStartDate is String) {
            startDate = DateTime.parse(rawStartDate);
            print('String을 DateTime으로 변환: $startDate');
          } else {
            print('⚠️ startDate 형식이 올바르지 않음: $rawStartDate');
            continue;
          }

          print('변환된 startDate: ${startDate.year}-${startDate.month}-${startDate.day}');
          print('비교 대상 date: ${date.year}-${date.month}-${date.day}');

          // 날짜 비교 (연도, 월, 일만 비교)
          bool isSameDate = startDate.year == date.year &&
              startDate.month == date.month &&
              startDate.day == date.day;

          print('날짜 일치 여부: $isSameDate');

          if (isSameDate) {
            String? startTime;
            String? endTime;

            // 시작 시간 처리
            if (data['startTime'] != null) {
              final startTimeData = data['startTime'];
              print('startTime 데이터: $startTimeData');
              if (startTimeData is Map<String, dynamic>) {
                final hour = startTimeData['hour'] ?? 0;
                final minute = startTimeData['minute'] ?? 0;
                startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                print('파싱된 시작 시간: $startTime');
              }
            }

            // 종료 시간 처리
            if (data['endTime'] != null) {
              final endTimeData = data['endTime'];
              print('endTime 데이터: $endTimeData');
              if (endTimeData is Map<String, dynamic>) {
                final hour = endTimeData['hour'] ?? 0;
                final minute = endTimeData['minute'] ?? 0;
                endTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                print('파싱된 종료 시간: $endTime');
              }
            }

            // 캘린더 이벤트 데이터 구성
            final calendarEvent = {
              'id': 'cal_${doc.id}',
              'title': data['title'] ?? '제목 없음',
              'type': 'calendar',
              'importance': 5,
              'urgency': 5,
              'estimatedDuration': _calculateCalendarEventDurationFromData(data),
              'startTime': startTime,
              'endTime': endTime,
              'location': data['location'] ?? '',
              'memo': data['memo'] ?? '',
              'description': data['description'] ?? '',
              'dueDate': null,
            };

            calendarEvents.add(calendarEvent);
            print('✅ 캘린더 이벤트 추가: ${data['title']} at $startTime');
          } else {
            print('❌ 날짜 불일치 - 이벤트 제외');
          }

          print(''); // 구분선
        } catch (e) {
          print('⚠️ 개별 이벤트 처리 오류: $e');
          continue;
        }
      }

      print('=== 최종 로드 결과 ===');
      print('로드된 캘린더 이벤트 수: ${calendarEvents.length}');
      print('===================');

      return calendarEvents;

    } catch (e) {
      print('❌ 캘린더 이벤트 로드 전체 오류: $e');
      return [];
    }
  }


  int _calculateCalendarEventDurationFromData(Map<String, dynamic> eventData) {
    try {
      if (eventData['startTime'] != null && eventData['endTime'] != null) {
        final startTimeData = eventData['startTime'];
        final endTimeData = eventData['endTime'];

        if (startTimeData is Map<String, dynamic> && endTimeData is Map<String, dynamic>) {
          final startHour = startTimeData['hour'] ?? 0;
          final endHour = endTimeData['hour'] ?? 0;
          final duration = endHour - startHour;
          return max(1, duration);
        }
      }
      return 1; // 기본값 1시간
    } catch (e) {
      print('캘린더 이벤트 지속시간 계산 오류: $e');
      return 1;
    }
  }



  int _calculateCalendarEventDuration(Map<String, dynamic> eventData) {
    try {
      if (eventData['startTime'] != null && eventData['endTime'] != null) {
        final startHour = eventData['startTime']['hour'] as int;
        final endHour = eventData['endTime']['hour'] as int;
        final duration = endHour - startHour;
        return max(1, duration);
      }
      return 1; // 기본값 1시간
    } catch (e) {
      print('캘린더 이벤트 지속시간 계산 오류: $e');
      return 1;
    }
  }

  List<Map<String, dynamic>> _generateFallbackScheduleWithCalendar(List<Map<String, dynamic>> allTasks) {
    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 캘린더 이벤트와 투두 태스크 분리
    final calendarEvents = allTasks.where((task) => task['type'] == 'calendar').toList();
    final todoTasks = allTasks.where((task) => task['type'] != 'calendar').toList();

    print('폴백 스케줄 생성: 캘린더 ${calendarEvents.length}개, 투두 ${todoTasks.length}개');

    // 1. 캘린더 이벤트 먼저 고정 배치 (시간이 정해진 것들)
    for (var event in calendarEvents) {
      if (event['startTime'] != null && event['startTime'].toString().isNotEmpty) {
        try {
          final startHour = int.parse(event['startTime'].split(':')[0]);
          final duration = event['estimatedDuration'] ?? 1;
          final endHour = (startHour + duration).clamp(0, 23);

          // 시간대 점유 표시
          for (int h = startHour; h < endHour; h++) {
            occupiedHours.add(h);
          }

          schedule.add({
            'id': event['id'],
            'title': event['title'],
            'time': event['startTime'],
            'endTime': event['endTime'] ?? '${endHour.toString().padLeft(2, '0')}:00',
            'priority': 5, // 캘린더는 최우선
            'description': event['memo'] ?? '',
            'memo': event['memo'] ?? '',
            'location': event['location'] ?? '',
            'dueDate': '',
            'confidence': 0.9, // 캘린더는 높은 신뢰도
            'aiReason': '캘린더에서 가져온 고정 일정',
            'taskType': 'calendar',
            'isCalendarEvent': true,
          });

          print('캘린더 이벤트 배치: ${event['title']} at ${event['startTime']}');
        } catch (e) {
          print('캘린더 이벤트 시간 파싱 오류: $e');
        }
      }
    }

    // 2. 투두 태스크 중요도/긴급도 순으로 정렬
    todoTasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore);
    });

    // 3. 시간이 지정된 투두 태스크 먼저 배치
    for (var task in todoTasks) {
      if (task['startTime'] != null && task['startTime'].toString().isNotEmpty) {
        try {
          final startHour = int.parse(task['startTime'].split(':')[0]);

          if (!occupiedHours.contains(startHour)) {
            occupiedHours.add(startHour);

            schedule.add({
              'id': task['id'],
              'title': task['title'],
              'time': task['startTime'],
              'endTime': task['endTime'] ?? '${(startHour + 1).toString().padLeft(2, '0')}:00',
              'priority': task['importance'] ?? 3,
              'description': task['memo'] ?? '',
              'memo': task['memo'] ?? '',
              'location': task['location'] ?? '',
              'dueDate': task['dueDate'] ?? '',
              'confidence': 0.7,
              'aiReason': '사용자 지정 시간에 따라 배치',
              'taskType': task['type'] ?? 'general',
              'isCalendarEvent': false,
            });

            // 처리됨 표시
            task['_processed'] = true;
          }
        } catch (e) {
          print('투두 시간 파싱 오류: $e');
        }
      }
    }

    // 4. 남은 투두 태스크들을 빈 시간대에 배치
    int currentHour = 9; // 오전 9시부터 시작

    for (var task in todoTasks) {
      if (task['_processed'] == true) continue;
      if (currentHour >= 21) break; // 오후 9시까지만

      // 사용 가능한 시간 찾기
      while (occupiedHours.contains(currentHour) && currentHour < 21) {
        currentHour++;
      }

      if (currentHour < 21) {
        occupiedHours.add(currentHour);

        schedule.add({
          'id': task['id'],
          'title': task['title'],
          'time': '${currentHour.toString().padLeft(2, '0')}:00',
          'endTime': '${(currentHour + 1).toString().padLeft(2, '0')}:00',
          'priority': task['importance'] ?? 3,
          'description': task['memo'] ?? '',
          'memo': task['memo'] ?? '',
          'location': task['location'] ?? '',
          'dueDate': task['dueDate'] ?? '',
          'confidence': 0.6,
          'aiReason': '중요도/긴급도에 따라 자동 배치',
          'taskType': task['type'] ?? 'general',
          'isCalendarEvent': false,
        });

        currentHour++;
      }
    }

    // 시간순 정렬
    schedule.sort((a, b) {
      final aTime = a['time'] ?? '00:00';
      final bTime = b['time'] ?? '00:00';
      return aTime.compareTo(bTime);
    });

    print('폴백 스케줄 생성 완료: 총 ${schedule.length}개 일정');
    return schedule;
  }

// 12시간 형식 변환 헬퍼 함수
  String _convertTo12HourFormat(String? time24) {
    if (time24 == null || time24.isEmpty) return '';

    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? parts[1] : '00';

      if (hour == 0) {
        return 'AM 12:$minute';
      } else if (hour < 12) {
        return 'AM ${hour.toString().padLeft(2, '0')}:$minute';
      } else if (hour == 12) {
        return 'PM 12:$minute';
      } else {
        return 'PM ${(hour - 12).toString().padLeft(2, '0')}:$minute';
      }
    } catch (e) {
      return time24;
    }
  }

// 폴백 스케줄 생성 함수
  List<Map<String, dynamic>> _generateFallbackSchedule(List<Map<String, dynamic>> tasks) {
    List<Map<String, dynamic>> schedule = [];
    Set<int> occupiedHours = {};

    // 중요도/긴급도 기준으로 정렬
    tasks.sort((a, b) {
      final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
      final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
      return bScore.compareTo(aScore);
    });

    int currentHour = 9; // 오전 9시부터 시작

    for (var task in tasks) {
      if (currentHour >= 21) break; // 오후 9시까지만

      // 고정 시간이 있는 경우
      if (task['startTime'] != null && task['startTime'].toString().isNotEmpty) {
        try {
          final fixedHour = int.parse(task['startTime'].split(':')[0]);
          if (!occupiedHours.contains(fixedHour)) {
            occupiedHours.add(fixedHour);

            schedule.add({
              'id': task['id'],
              'title': task['title'],
              'time': '${fixedHour.toString().padLeft(2, '0')}:00',
              'endTime': '${(fixedHour + 1).toString().padLeft(2, '0')}:00',
              'priority': task['importance'] ?? 3,
              'description': task['memo'] ?? '',
              'memo': task['memo'] ?? '',
              'location': task['location'] ?? '',
              'dueDate': task['dueDate'] ?? '',
              'confidence': 0.6, // 폴백 스케줄의 기본 신뢰도
              'aiReason': '기본 스케줄링 규칙에 따라 배치되었습니다',
            });
            continue;
          }
        } catch (e) {
          // 파싱 실패시 아래 로직으로 계속
        }
      }

      // 사용 가능한 시간에 배치
      while (occupiedHours.contains(currentHour) && currentHour < 21) {
        currentHour++;
      }

      if (currentHour < 21) {
        occupiedHours.add(currentHour);

        schedule.add({
          'id': task['id'],
          'title': task['title'],
          'time': '${currentHour.toString().padLeft(2, '0')}:00',
          'endTime': '${(currentHour + 1).toString().padLeft(2, '0')}:00',
          'priority': task['importance'] ?? 3,
          'description': task['memo'] ?? '',
          'memo': task['memo'] ?? '',
          'location': task['location'] ?? '',
          'dueDate': task['dueDate'] ?? '',
          'confidence': 0.5, // 폴백 스케줄의 낮은 신뢰도
          'aiReason': '중요도 순서에 따라 배치되었습니다',
        });

        currentHour++;
      }
    }

    return schedule;
  }


// AI 피드백 다이얼로그 표시
  void _showAIFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Colors.purple),
            SizedBox(width: 8),
            Text('AI 추천 평가'),
          ],
        ),
        content: Text('오늘의 AI 스케줄 추천이 도움이 되었나요?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitAIFeedback('thumbs_down');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thumb_down, color: Colors.red),
                SizedBox(width: 4),
                Text('별로예요'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitAIFeedback('thumbs_up');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thumb_up, color: Colors.white),
                SizedBox(width: 4),
                Text('좋아요', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAIFeedback(String feedback) async {
    try {
      final plannerTasks = _taskDataService.getPlannerTasksForDate(selectedDate);

      final scheduledTasks = plannerTasks.map((task) => {
        'taskId': task.id,
        'taskTitle': task.title,
        'scheduledTime': task.time,
        'importance': task.importance,
        'urgency': task.urgency,
        'isCompleted': task.isCompleted,
      }).toList();

      final String endpoint = '/submit_feedback';
      final String fullUrl = '$BASE_SERVER_URL$endpoint';

      print('📝 피드백 제출: $fullUrl');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userFeedback': feedback,
          'scheduledTasks': scheduledTasks,
          'actualFollowedSchedule': feedback == 'thumbs_up',
          'userComment': '',
          'feedbackDate': selectedDate.toIso8601String().split('T')[0],
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(Duration(seconds: 15));

      print('📝 피드백 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        String message = '피드백 감사합니다!';
        if (responseData['modelUpdated'] == true) {
          message += ' AI 모델이 개선되었습니다.';
        }
        _showSnackBar(message);
        print('✅ AI 피드백 제출 완료: $feedback');
      } else {
        throw Exception('피드백 제출 실패: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ 피드백 제출 오류: $e');
      _showSnackBar('피드백 제출에 실패했습니다. 나중에 다시 시도해주세요.');
    }
  }
}


// 태스크 타입 분류 헬퍼 함수
String _getTaskType(String title) {
  final lowerTitle = title.toLowerCase();

  if (lowerTitle.contains('회의') || lowerTitle.contains('미팅') || lowerTitle.contains('meeting')) {
    return 'meeting';
  } else if (lowerTitle.contains('운동') || lowerTitle.contains('헬스') || lowerTitle.contains('조깅')) {
    return 'exercise';
  } else if (lowerTitle.contains('공부') || lowerTitle.contains('학습') || lowerTitle.contains('강의')) {
    return 'study';
  } else if (lowerTitle.contains('식사') || lowerTitle.contains('점심') || lowerTitle.contains('저녁')) {
    return 'meal';
  } else if (lowerTitle.contains('업무') || lowerTitle.contains('작업') || lowerTitle.contains('프로젝트')) {
    return 'work';
  } else if (lowerTitle.contains('병원') || lowerTitle.contains('의료') || lowerTitle.contains('검진')) {
    return 'medical';
  } else if (lowerTitle.contains('쇼핑') || lowerTitle.contains('구매') || lowerTitle.contains('마트')) {
    return 'shopping';
  } else {
    return 'general';
  }
}


// 시간 문자열 파싱 헬퍼 함수
DateTime? _parseTimeString(String timeString) {
  try {
    // "AM 09:00" 또는 "PM 02:30" 형식 처리
    final cleanTime = timeString.replaceAll(RegExp(r'[^\d:]'), '');
    final parts = cleanTime.split(':');

    if (parts.length >= 2) {
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // AM/PM 처리
      if (timeString.toUpperCase().contains('PM') && hour != 12) {
        hour += 12;
      } else if (timeString.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
  } catch (e) {
    print('시간 파싱 오류: $e');
  }
  return null;
}

// AI 스케줄링 상태 확인 헬퍼 함수
bool _isAISchedulingAvailable() {
  // 네트워크 연결 상태, 서버 상태 등을 확인
  // 실제 구현에서는 connectivity_plus 패키지 등을 사용할 수 있음
  return true; // 임시로 항상 true 반환
}

// AI 추천 시간대 분석 함수
Map<String, dynamic> _analyzeAIRecommendations(List<Map<String, dynamic>> schedule) {
  if (schedule.isEmpty) {
    return {
      'totalTasks': 0,
      'averageConfidence': 0.0,
      'peakHours': [],
      'lowConfidenceTasks': [],
    };
  }

  // 신뢰도 분석
  final confidences = schedule
      .map((item) => item['confidence'] as double? ?? 0.0)
      .toList();
  final averageConfidence = confidences.isNotEmpty
      ? confidences.reduce((a, b) => a + b) / confidences.length
      : 0.0;

  // 낮은 신뢰도 태스크 찾기
  final lowConfidenceTasks = schedule
      .where((item) => (item['confidence'] as double? ?? 0.0) < 0.7)
      .map((item) => item['title'])
      .toList();

  // 시간대별 태스크 분포 분석
  final hourCounts = <int, int>{};
  for (var item in schedule) {
    try {
      final timeStr = item['time'] as String;
      final hour = int.parse(timeStr.split(':')[0]);
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    } catch (e) {
      // 시간 파싱 실패시 무시
    }
  }

  // 피크 시간대 찾기
  final maxCount = hourCounts.values.isNotEmpty
      ? hourCounts.values.reduce((a, b) => a > b ? a : b)
      : 0;
  final peakHours = hourCounts.entries
      .where((entry) => entry.value == maxCount)
      .map((entry) => entry.key)
      .toList();

  return {
    'totalTasks': schedule.length,
    'averageConfidence': averageConfidence,
    'peakHours': peakHours,
    'lowConfidenceTasks': lowConfidenceTasks,
    'hourDistribution': hourCounts,
  };
}

// AI 추천 결과 로깅 함수
void _logAIRecommendation(Map<String, dynamic> analysis) {
  print('=== AI 추천 분석 결과 ===');
  print('총 태스크 수: ${analysis['totalTasks']}');
  print('평균 신뢰도: ${(analysis['averageConfidence'] as double).toStringAsFixed(2)}');
  print('피크 시간대: ${analysis['peakHours']}');

  if ((analysis['lowConfidenceTasks'] as List).isNotEmpty) {
    print('낮은 신뢰도 태스크: ${analysis['lowConfidenceTasks'].join(', ')}');
  }

  print('시간대별 분포: ${analysis['hourDistribution']}');
  print('========================');
}


String? _normalizeTime(String? time) {
  if (time == null) return null;

  // AM/PM 형식 처리
  bool isPM = false;
  if (time.contains('PM')) {
    isPM = true;
    time = time.replaceAll('PM', '').trim();
  } else if (time.contains('AM')) {
    time = time.replaceAll('AM', '').trim();
  }

  final parts = time.split(':');
  if (parts.length != 2) return time;

  // 시간 값 파싱 및 유효성 검사
  int hour;
  try {
    hour = int.parse(parts[0]);

    // AM/PM 형식인 경우 24시간제로 변환
    if (isPM && hour < 12) {
      hour += 12; // PM일 경우 12를 더함 (PM 12시는 예외)
    } else if (!isPM && hour == 12) {
      hour = 0; // AM 12시는 0시로 변환
    }

    // 시간 범위 유효성 검사: 0-23 범위로 제한
    hour = hour.clamp(0, 23);
  } catch (e) {
    hour = 9; // 기본값 설정
  }

  // 분 값 파싱 및 유효성 검사
  int minute;
  try {
    minute = int.parse(parts[1]);
    // 분 범위 유효성 검사: 0-59 범위로 제한
    minute = minute.clamp(0, 59);
  } catch (e) {
    minute = 0; // 기본값 설정
  }

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}


// _generateLocalSchedule 함수 수정
List<Map<String, dynamic>> generateLocalSchedule(
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> calendar) {

  List<Map<String, dynamic>> schedule = [];
  Set<int> occupiedHours = {};

  // 1. 캘린더 이벤트 먼저 추가 (고정 일정)
  for (var event in calendar) {
    if (event['startTime'] != null) {
      // 시간 정규화
      final normalizedStartTime = _normalizeTime(event['startTime']);
      final normalizedEndTime = _normalizeTime(event['endTime']);

      int startHour;
      try {
        startHour = int.parse(normalizedStartTime!.split(':')[0]);
        startHour = startHour.clamp(0, 23); // 범위 확인
      } catch (e) {
        startHour = 9; // 기본값
      }

      int endHour;
      if (normalizedEndTime != null) {
        try {
          endHour = int.parse(normalizedEndTime.split(':')[0]);
          endHour = endHour.clamp(0, 23); // 범위 확인
        } catch (e) {
          endHour = startHour + 1; // 기본값
        }
      } else {
        endHour = startHour + 1;
      }

      // 시간이 뒤바뀐 경우 수정
      if (endHour < startHour) {
        endHour = startHour + 1;
      }

      // 시간대 차지 표시
      for (int h = startHour; h <= endHour; h++) {
        occupiedHours.add(h.clamp(0, 23));
      }

      schedule.add({
        'id': 'cal_${schedule.length}',
        'title': '(일정) ${event['title']}',
        'time': normalizedStartTime,
        'endTime': normalizedEndTime ?? '${(startHour + 1).toString().padLeft(2, '0')}:00',
        'priority': 3, // 최우선
        'description': '캘린더 일정',
        'memo': '',
        'location': event['location'] ?? '',
      });
    }
  }

  // 2. 작업 중요도/긴급도 기준 정렬
  tasks.sort((a, b) {
    final aScore = (a['importance'] ?? 1) + (a['urgency'] ?? 1);
    final bScore = (b['importance'] ?? 1) + (b['urgency'] ?? 1);
    return bScore.compareTo(aScore); // 높은 점수가 먼저 오도록
  });

  // 3. 먼저 사용자가 지정한 시간이 있는 작업 추가
  for (var task in tasks) {
    // 사용자가 지정한 시간이 있는지 확인
    final userTime = task['time'];

    if (userTime != null && userTime.toString().isNotEmpty) {
      // 시간 정규화
      final normalizedTime = _normalizeTime(userTime.toString());
      final normalizedEndTime = _normalizeTime(task['endTime']?.toString());

      // 시작 시간의 시간대만 추출
      int startHour;
      try {
        startHour = int.parse(normalizedTime!.split(':')[0]);
        startHour = startHour.clamp(0, 23); // 범위 확인
      } catch (e) {
        startHour = 9; // 기본값
      }

      // 종료 시간 설정
      String endTime;
      if (normalizedEndTime != null && normalizedEndTime.isNotEmpty) {
        endTime = normalizedEndTime;
      } else {
        // 기본 종료 시간은 시작 + 1시간
        endTime = '${((startHour + 1) % 24).toString().padLeft(2, '0')}:00';
      }

      // 시간대 차지 표시
      occupiedHours.add(startHour);

      // 중요도/긴급도에 따른 우선순위 설정
      final importance = task['importance'] ?? 1;
      final urgency = task['urgency'] ?? 1;
      final priority = importance > urgency ? importance : urgency;

      schedule.add({
        'id': 'task_${schedule.length}',
        'title': task['title'],
        'time': normalizedTime,
        'endTime': endTime,
        'priority': priority,
        'description': '중요도: $importance, 긴급도: $urgency',
        'memo': '',
        'location': '',
        'dueDate': task['dueDate'],
      });

      // 이미 처리된 작업은 표시
      task['_processed'] = true;
    }
  }

  // 4. 남은 시간대에 시간이 지정되지 않은 작업 배치
  int startHour = 9; // 오전 9시부터 시작

  for (var task in tasks) {
    // 이미 처리된 작업은 건너뛰기
    if (task['_processed'] == true) continue;

    // 하루 업무 시간 9시-21시로 제한
    if (startHour >= 21) break;

    // 사용 가능한 시간 찾기
    while (occupiedHours.contains(startHour)) {
      startHour++;
      if (startHour >= 21) break;
    }

    if (startHour >= 21) break;

    // 중요도/긴급도에 따른 우선순위 설정
    final importance = task['importance'] ?? 1;
    final urgency = task['urgency'] ?? 1;
    final priority = importance > urgency ? importance : urgency;

    schedule.add({
      'id': 'task_${schedule.length}',
      'title': task['title'],
      'time': '${startHour.toString().padLeft(2, '0')}:00',
      'endTime': '${(startHour + 1).toString().padLeft(2, '0')}:00',
      'priority': priority,
      'description': '중요도: $importance, 긴급도: $urgency',
      'memo': '',
      'location': '',
      'dueDate': task['dueDate'],
    });

    occupiedHours.add(startHour);
    startHour++;
  }

  // 시간순 정렬
  schedule.sort((a, b) {
    if (a['time'] == null) return 1;
    if (b['time'] == null) return -1;
    return a['time'].toString().compareTo(b['time'].toString());
  });

  return schedule;
}


// 기본 추천 생성 함수 (최후 수단)
Future<List<TaskRecommendation>> _generateBasicRecommendations(
    List<Todo_Task> plannerTasks, List<Todo_Task> todoTasks) async {

  final recommendations = <TaskRecommendation>[];
  final occupiedHours = <int>{};

  // 점유된 시간 계산
  for (var task in plannerTasks) {
    if (task.time != null) {
      try {
        final hour = _parseTimeToHour(task.time!);
        occupiedHours.add(hour);
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }
  }

  // 기본 추천 목록
  final basicRecommendations = [
    {
      'title': '하루 마무리 및 내일 준비',
      'time': 20,
      'confidence': 0.8,
      'reason': '하루를 정리하고 내일을 준비하는 시간',
    },
    {
      'title': '오후 휴식 및 에너지 충전',
      'time': 15,
      'confidence': 0.75,
      'reason': '오후 피로 회복을 위한 휴식',
    },
    {
      'title': '아침 계획 수립',
      'time': 8,
      'confidence': 0.7,
      'reason': '효율적인 하루 시작을 위한 계획',
    },
    {
      'title': '중간 점검 및 조정',
      'time': 12,
      'confidence': 0.65,
      'reason': '오전 활동 점검 및 오후 계획 조정',
    },
    {
      'title': '가벼운 운동 및 스트레칭',
      'time': 18,
      'confidence': 0.7,
      'reason': '건강 관리를 위한 신체 활동',
    },
    {
      'title': '독서 및 자기계발',
      'time': 21,
      'confidence': 0.6,
      'reason': '지식 향상과 개인 성장',
    },
  ];

  for (var rec in basicRecommendations) {
    final hour = rec['time'] as int;
    if (!occupiedHours.contains(hour)) {
      recommendations.add(TaskRecommendation(
        taskId: 'basic_${recommendations.length}',
        taskTitle: rec['title'] as String,
        recommendedTime: '${hour.toString().padLeft(2, '0')}:00',
        confidence: rec['confidence'] as double,
        reason: rec['reason'] as String,
      ));

      if (recommendations.length >= 3) break; // 최대 3개까지
    }
  }

  return recommendations;
}

// 개선된 월 선택기 위젯
class ImprovedMonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onMonthChanged;

  const ImprovedMonthSelector({
    Key? key,
    required this.selectedDate,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              final newDate = DateTime(selectedDate.year, selectedDate.month - 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),
          GestureDetector(
            onTap: () => _showMonthYearPicker(context),
            child: Text(
              '${selectedDate.year}년 ${selectedDate.month}월',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () {
              final newDate = DateTime(selectedDate.year, selectedDate.month + 1, selectedDate.day);
              onMonthChanged(newDate);
            },
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          child: YearPicker(
            selectedDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onChanged: (DateTime dateTime) {
              onMonthChanged(dateTime);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

// _parseTimeToHour 함수 추가 - DailyPlannerPageState 클래스 내부에 추가하세요
int _parseTimeToHour(String timeString) {
  try {
    // "AM 09:00" 형식 처리
    if (timeString.contains('AM') || timeString.contains('PM')) {
      final isAM = timeString.contains('AM');
      final timePart = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

      int hour;
      if (timePart.contains(':')) {
        hour = int.parse(timePart.split(':')[0].trim());
      } else {
        hour = int.parse(timePart);
      }

      // 12시간제를 24시간제로 변환
      if (!isAM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return hour;
    }

    // "HH:mm" 형식 처리 (24시간제)
    if (timeString.contains(':')) {
      return int.parse(timeString.split(':')[0]);
    }

    // 숫자만 있는 경우
    return int.parse(timeString);
  } catch (e) {
    print('시간 파싱 오류: $e, 입력값: $timeString');
    return 9; // 기본값
  }
}

// 개선된 주간 캘린더 위젯
class EnhancedWeeklyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const EnhancedWeeklyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  _EnhancedWeeklyCalendarState createState() => _EnhancedWeeklyCalendarState();
}

class _EnhancedWeeklyCalendarState extends State<EnhancedWeeklyCalendar> {
  late PageController _pageController;
  late int _currentPage;
  final int _totalWeeks = 100;
  late DateTime _baseDate;
  late DateTime _currentStartDate;

  @override
  void initState() {
    super.initState();
    _baseDate = _findFirstDayOfWeek(DateTime.now().subtract(Duration(days: 50 * 7)));
    _currentPage = _getPageForDate(widget.selectedDate);
    _pageController = PageController(initialPage: _currentPage);
    _currentStartDate = _getStartDateForPage(_currentPage);
  }

  @override
  void didUpdateWidget(covariant EnhancedWeeklyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final newPage = _getPageForDate(widget.selectedDate);
      if (newPage != _currentPage) {
        _currentPage = newPage;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _currentStartDate = _getStartDateForPage(_currentPage);
      }
    }
  }

  DateTime _findFirstDayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _getPageForDate(DateTime date) {
    final firstDayOfWeek = _findFirstDayOfWeek(date);
    final diffDays = firstDayOfWeek.difference(_baseDate).inDays;
    return (diffDays / 7).round();
  }

  DateTime _getStartDateForPage(int page) {
    return _baseDate.add(Duration(days: page * 7));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
            _currentStartDate = _getStartDateForPage(page);
          });
        },
        itemBuilder: (context, index) {
          final weekStart = _getStartDateForPage(index);
          return _buildWeek(weekStart);
        },
        itemCount: _totalWeeks,
      ),
    );
  }

  Widget _buildWeek(DateTime weekStart) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final currentDate = weekStart.add(Duration(days: index));
            return Container(
              width: 40,
              child: Center(
                child: Text(
                  _getWeekdayString(currentDate.weekday),
                  style: TextStyle(
                    color: currentDate.weekday >= 6
                        ? (currentDate.weekday == 6 ? Colors.blue : Colors.red)
                        : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final currentDate = weekStart.add(Duration(days: index));
            final isSelected = _isSameDay(currentDate, widget.selectedDate);
            final isToday = _isSameDay(currentDate, DateTime.now());
            return GestureDetector(
              onTap: () => widget.onDateSelected(currentDate),
              child: Container(
                width: 40,
                height: 40,
                decoration: isSelected
                    ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.2),
                )
                    : isToday
                    ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple, width: 1),
                )
                    : null,
                child: Center(
                  child: Text(
                    '${currentDate.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.purple
                          : (currentDate.weekday >= 6
                          ? (currentDate.weekday == 6 ? Colors.blue : Colors.red)
                          : Colors.black87),
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _getWeekdayString(dynamic weekday) {
    // weekday를 안전하게 int로 변환
    int day;
    if (weekday is String) {
      day = int.tryParse(weekday) ?? 1;
    } else if (weekday is int) {
      day = weekday;
    } else {
      day = 1; // 기본값
    }

    switch (day) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    //_insightsUpdateTimer?.cancel();
    super.dispose();
  }
}

Color _getFixedColorForTask(String title) {
  final colors = [
    Colors.purple.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.orange.shade100,
    Colors.red.shade100,
    Colors.teal.shade100,
    Colors.amber.shade100,
  ];
  return colors[title.hashCode % colors.length];
}

class PlannerOnlyProgressScreen extends StatelessWidget {
  final List<Todo_Task> plannerTasks;
  final double plannerProgressPercentage;

  const PlannerOnlyProgressScreen({
    Key? key,
    required this.plannerTasks,
    required this.plannerProgressPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalPlannerTasks = plannerTasks.length;
    int completedPlannerTasks = plannerTasks.where((task) => task.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Your Progress Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          ),
          const SizedBox(height: 15),

          // 플래너 진행률만 표시
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              height: 10,
                              width: constraints.maxWidth * (plannerProgressPercentage / 100),  // ← 0.65 제거!
                              decoration: BoxDecoration(
                                color: plannerProgressPercentage == 100
                                    ? const Color(0xFFD1B3F3) // 100% 완료시: 진한 파스텔 보라색
                                    : const Color(0xFFECDBF9), // 진행중: 연한 파스텔 보라색
                                borderRadius: BorderRadius.circular(5),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${plannerProgressPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedPlannerTasks/$totalPlannerTasks Tasks Complete',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (plannerProgressPercentage == 100)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🎉 완료!',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// 랜덤한 밝은 파스텔 색상 생성
Color getBrightPastelColor() {
  final Random random = Random();
  final List<Color> brightPastelColors = [
    const Color(0xFFFFE6E6),
    const Color(0xFFFFEDCC),
    const Color(0xFFFFFFCC),
    const Color(0xFFE6FFCC),
    const Color(0xFFCCFFE1),
    const Color(0xFFCCFFFF),
    const Color(0xFFCCE6FF),
    const Color(0xFFE6CCFF),
    const Color(0xFFFDD5DF),
    const Color(0xFFFFDAB9),
    const Color(0xFFE0F7FA),
    const Color(0xFFF1F8E9),
    const Color(0xFFFCE4EC),
    const Color(0xFFF3E5F5),
    const Color(0xFFE8F5E9),
  ];
  return brightPastelColors[random.nextInt(brightPastelColors.length)];
}
