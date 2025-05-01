import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum MoodState {
  veryGood,
  good,
  neutral,
  bad,
  veryBad,
}

class DiaryEntry {
  final String id;
  final DateTime date;
  final String content;
  final MoodState mood;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.content,
    required this.mood,
  });

  // Firestore 문서에서 DiaryEntry 객체 생성
  factory DiaryEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // mood 필드가 없는 이전 데이터를 위한 기본값 처리
    MoodState parsedMood = MoodState.neutral;
    if (data.containsKey('mood')) {
      parsedMood = MoodState.values[data['mood'] as int];
    }

    return DiaryEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      content: data['content'] as String,
      mood: parsedMood,
    );
  }

  // DiaryEntry 객체를 Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'content': content,
      'mood': mood.index,
    };
  }

  // 편집을 위한 복사본 생성
  DiaryEntry copyWith({
    String? id,
    DateTime? date,
    String? content,
    MoodState? mood,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      content: content ?? this.content,
      mood: mood ?? this.mood,
    );
  }
}

// MoodState의 한글 이름을 반환하는 확장 함수
extension MoodStateExtension on MoodState {
  String get koreanName {
    switch (this) {
      case MoodState.veryGood:
        return '매우 좋음';
      case MoodState.good:
        return '좋음';
      case MoodState.neutral:
        return '보통';
      case MoodState.bad:
        return '나쁨';
      case MoodState.veryBad:
        return '매우 나쁨';
    }
  }

  Color get color {
    switch (this) {
      case MoodState.veryGood:
        return Color(0xFFB39DDB); // 연보라색
      case MoodState.good:
        return Color(0xFFD1C4E9); // 밝은 연보라색
      case MoodState.neutral:
        return Color(0xFFE0E0E0); // 회색
      case MoodState.bad:
        return Color(0xFFBDBDBD); // 어두운 회색
      case MoodState.veryBad:
        return Color(0xFF9E9E9E); // 더 어두운 회색
    }
  }

  IconData get icon {
    switch (this) {
      case MoodState.veryGood:
        return Icons.sentiment_very_satisfied;
      case MoodState.good:
        return Icons.sentiment_satisfied;
      case MoodState.neutral:
        return Icons.sentiment_neutral;
      case MoodState.bad:
        return Icons.sentiment_dissatisfied;
      case MoodState.veryBad:
        return Icons.sentiment_very_dissatisfied;
    }
  }
}