// lib/services/ai_scheduling_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AISchedulingService {
  static const String AI_SERVER_URL = 'https://railwavve-production-68d4.up.railway.app'; // 실제 서버 URL로 변경
  // 개발용: 'http://localhost:5000' 또는 'http://10.0.2.2:5000' (안드로이드 에뮬레이터)

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 사용자 행동 데이터 기록
  Future<bool> recordUserBehavior({
    required String userId,
    required String taskId,
    required String taskType,
    required DateTime scheduledTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    required String completionStatus, // completed, delayed, skipped, partial
    required int importance,
    required int urgency,
    String environment = 'home',
    String mood = 'neutral',
    int completionRating = 3,
    int delayMinutes = 0,
  }) async {
    try {
      // 로컬 Firestore에 저장
      await _firestore.collection('user_behavior_patterns').add({
        'userId': userId,
        'taskId': taskId,
        'taskType': taskType,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'actualStartTime': actualStartTime != null ? Timestamp.fromDate(actualStartTime) : null,
        'actualEndTime': actualEndTime != null ? Timestamp.fromDate(actualEndTime) : null,
        'completionStatus': completionStatus,
        'dayOfWeek': scheduledTime.weekday - 1, // 0=Monday
        'timeSlot': scheduledTime.hour,
        'importance': importance,
        'urgency': urgency,
        'environment': environment,
        'mood': mood,
        'completionRating': completionRating,
        'delayMinutes': delayMinutes,
        'createdAt': Timestamp.now(),
      });

      // AI 서버에도 전송
      final response = await http.post(
        Uri.parse('$AI_SERVER_URL/record_behavior'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'taskId': taskId,
          'taskType': taskType,
          'scheduledTime': scheduledTime.toIso8601String(),
          'actualStartTime': actualStartTime?.toIso8601String(),
          'actualEndTime': actualEndTime?.toIso8601String(),
          'completionStatus': completionStatus,
          'importance': importance,
          'urgency': urgency,
          'environment': environment,
          'mood': mood,
          'completionRating': completionRating,
          'delayMinutes': delayMinutes,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('행동 데이터 기록 실패: $e');
      return false;
    }
  }

  /// AI 기반 스케줄 예측 요청
  Future<AISchedulePrediction?> predictOptimalSchedule({
    required String userId,
    required List<Map<String, dynamic>> tasks,
    DateTime? targetDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$AI_SERVER_URL/predict_schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'tasks': tasks,
          'date': (targetDate ?? DateTime.now()).toIso8601String().split('T')[0],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AISchedulePrediction.fromJson(data);
      }

      return null;
    } catch (e) {
      print('AI 스케줄 예측 실패: $e');
      return null;
    }
  }

  /// 사용자 피드백 제출
  Future<bool> submitFeedback({
    required String userId,
    String? recommendationId,
    required List<Map<String, dynamic>> scheduledTasks,
    required String userFeedback, // thumbs_up, thumbs_down, neutral
    bool actualFollowedSchedule = false,
    String userComment = '',
    String improvementSuggestion = '',
  }) async {
    try {
      // Firestore에 저장
      await _firestore.collection('ai_recommendation_feedback').add({
        'userId': userId,
        'recommendationId': recommendationId,
        'scheduledTasks': scheduledTasks,
        'userFeedback': userFeedback,
        'actualFollowedSchedule': actualFollowedSchedule,
        'userComment': userComment,
        'improvementSuggestion': improvementSuggestion,
        'createdAt': Timestamp.now(),
      });

      // AI 서버에 전송
      final response = await http.post(
        Uri.parse('$AI_SERVER_URL/submit_feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'recommendationId': recommendationId,
          'scheduledTasks': scheduledTasks,
          'userFeedback': userFeedback,
          'actualFollowedSchedule': actualFollowedSchedule,
          'userComment': userComment,
          'improvementSuggestion': improvementSuggestion,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('피드백 제출 실패: $e');
      return false;
    }
  }

  /// 모델 훈련 요청
  Future<bool> requestModelTraining(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$AI_SERVER_URL/train_model'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('모델 훈련 요청 실패: $e');
      return false;
    }
  }

  /// 사용자 인사이트 조회
  Future<UserInsights?> getUserInsights(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$AI_SERVER_URL/get_user_insights?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserInsights.fromJson(data);
      }

      return null;
    } catch (e) {
      print('인사이트 조회 실패: $e');
      return null;
    }
  }

  /// 사용자가 태스크 완료 시 자동으로 행동 데이터 기록
  Future<void> recordTaskCompletion({
    required String userId,
    required String taskId,
    required String taskTitle,
    required String taskType,
    required DateTime scheduledTime,
    required DateTime actualCompletionTime,
    required int importance,
    required int urgency,
    bool wasCompleted = true,
  }) async {
    final delayMinutes = actualCompletionTime.difference(scheduledTime).inMinutes;
    final completionStatus = wasCompleted
        ? (delayMinutes > 30 ? 'delayed' : 'completed')
        : 'skipped';

    await recordUserBehavior(
      userId: userId,
      taskId: taskId,
      taskType: taskType,
      scheduledTime: scheduledTime,
      actualStartTime: actualCompletionTime,
      actualEndTime: actualCompletionTime,
      completionStatus: completionStatus,
      importance: importance,
      urgency: urgency,
      delayMinutes: delayMinutes.abs(),
    );
  }

  /// 현재 시간대별 사용자 에너지 레벨 예측
  double getUserEnergyLevel(int hour) {
    // 시간대별 기본 에너지 레벨 (사용자 데이터로 개인화 가능)
    if (hour >= 6 && hour < 10) return 0.9;   // 아침
    if (hour >= 10 && hour < 14) return 0.8;  // 오전
    if (hour >= 14 && hour < 18) return 0.7;  // 오후
    if (hour >= 18 && hour < 22) return 0.6;  // 저녁
    return 0.3; // 늦은 밤/새벽
  }
}

/// AI 스케줄 예측 결과 모델
class AISchedulePrediction {
  final bool success;
  final List<TaskRecommendation> predictions;
  final PredictionMetadata metadata;

  AISchedulePrediction({
    required this.success,
    required this.predictions,
    required this.metadata,
  });

  factory AISchedulePrediction.fromJson(Map<String, dynamic> json) {
    return AISchedulePrediction(
      success: json['success'] ?? false,
      predictions: (json['predictions'] as List<dynamic>? ?? [])
          .map((p) => TaskRecommendation.fromJson(p))
          .toList(),
      metadata: PredictionMetadata.fromJson(json['metadata'] ?? {}),
    );
  }
}

/// 개별 태스크 추천 정보
class TaskRecommendation {
  final String taskId;
  final String taskTitle;
  late final String recommendedTime;
  final double confidence;
  final String reason;
  final List<AlternativeTime> alternatives;

  TaskRecommendation({
    required this.taskId,
    required this.taskTitle,
    required this.recommendedTime,
    required this.confidence,
    required this.reason,
    this.alternatives = const [],
  });

  factory TaskRecommendation.fromJson(Map<String, dynamic> json) {
    return TaskRecommendation(
      taskId: json['taskId'] ?? '',
      taskTitle: json['taskTitle'] ?? '',
      recommendedTime: json['recommendedTime'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((a) => AlternativeTime.fromJson(a))
          .toList(),
    );
  }
}

/// 대안 시간대
class AlternativeTime {
  final String time;
  final double confidence;

  AlternativeTime({required this.time, required this.confidence});

  factory AlternativeTime.fromJson(Map<String, dynamic> json) {
    return AlternativeTime(
      time: json['time'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// 예측 메타데이터
class PredictionMetadata {
  final String predictionDate;
  final int taskCount;
  final double overallConfidence;

  PredictionMetadata({
    required this.predictionDate,
    required this.taskCount,
    required this.overallConfidence,
  });

  factory PredictionMetadata.fromJson(Map<String, dynamic> json) {
    return PredictionMetadata(
      predictionDate: json['prediction_date'] ?? '',
      taskCount: json['task_count'] ?? 0,
      overallConfidence: (json['overall_confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// 사용자 인사이트 모델
class UserInsights {
  final Map<String, dynamic> insights;
  final String dataPeriod;
  final String generatedAt;

  UserInsights({
    required this.insights,
    required this.dataPeriod,
    required this.generatedAt,
  });

  factory UserInsights.fromJson(Map<String, dynamic> json) {
    return UserInsights(
      insights: json['insights'] ?? {},
      dataPeriod: json['data_period'] ?? '',
      generatedAt: json['generated_at'] ?? '',
    );
  }

  // 편의 메서드들
  double get completionRate => (insights['전체_완료율'] ?? 0.0).toDouble();
  int get bestProductiveHour => insights['최고_생산성_시간대'] ?? 9;
  String get favoriteDay => insights['선호하는_요일'] ?? '월';
  double get averageDelay => (insights['평균_지연시간'] ?? 0.0).toDouble();
}