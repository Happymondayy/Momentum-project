import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrencePattern {
  daily,    // 매일
  weekly,   // 매주
  monthly,  // 매월
  yearly,   // 매년
}

class Event {
  final DateTime createdAt;
  final String? userId;
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String memo;
  final String location;
  final bool isRepeating;
  final String? repeatOption;
  final List<int>? repeatDays;
  final int? repeatCustomDays;
  final bool isAllDay;
  final String? reminder;
  bool isReminderScheduled;
  final DateTime? repeatUntil;    // 반복 종료일
  final String? parentEventId; // 부모 반복 이벤트 ID
  final String isLongTerm;
  final int? term;

  Event({
    required this.createdAt,
    required this.userId,
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    this.memo = '',
    this.location = '',
    this.isRepeating = false,
    this.repeatOption,
    this.repeatDays,
    this.repeatCustomDays,
    this.isAllDay = false,
    this.reminder,
    this.isReminderScheduled = false,
    this.repeatUntil,
    this.parentEventId,
    this.isLongTerm = '',
    this.term = 0,
  });

  // Create a copy of this event with optional modified fields
  Event copyWith({
    DateTime? createdAt,
    String? userId,
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? memo,
    String? location,
    bool? isRepeating,
    String? repeatOption,
    List<int>? repeatDays,
    int? repeatCustomDays,
    bool? isAllDay,
    String? reminder,
    bool? isReminderScheduled,
    DateTime? repeatUntil,
    String? parentEventId,
    bool clearTimes = false,  // 시간을 명시적으로 null로 설정하는 플래그
    String? isLongTerm,
    int? term,
  }) {
    final newIsAllDay = isAllDay ?? this.isAllDay;

    return Event(
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      // isAllDay가 true이거나 clearTimes가 true면 시간을 null로 설정
      startTime: (newIsAllDay || clearTimes) ? null : (startTime ?? this.startTime),
      endTime: (newIsAllDay || clearTimes) ? null : (endTime ?? this.endTime),
      memo: memo ?? this.memo,
      location: location ?? this.location,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatOption: repeatOption ?? this.repeatOption,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatCustomDays: repeatCustomDays ?? this.repeatCustomDays,
      isAllDay: newIsAllDay,
      reminder: reminder ?? this.reminder,
      isReminderScheduled: isReminderScheduled ?? this.isReminderScheduled,
      repeatUntil: repeatUntil ?? this.repeatUntil,
      parentEventId: parentEventId ?? this.parentEventId,
      isLongTerm: isLongTerm ?? this.isLongTerm,
      term: term ?? this.term,
    );
  }

  // Firebase에 저장하기 위한 Map 변환 메서드 (CalendarScreen 코드와 일치하도록 수정)
  Map<String, dynamic> toMap() {
    // isAllDay가 true면 시간 데이터를 null로 설정
    final startTimeMap = (!isAllDay && startTime != null) ? {
      'hour': startTime!.hour,
      'minute': startTime!.minute,
    } : null;

    final endTimeMap = (!isAllDay && endTime != null) ? {
      'hour': endTime!.hour,
      'minute': endTime!.minute,
    } : null;

    return {
      'createdAt': createdAt,
      'userId' : userId ?? '',
      'title': title,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'startTime': startTimeMap,
      'endTime': endTimeMap,
      'memo': memo,
      'location': location,
      'isRepeating': isRepeating,
      'repeatOption': repeatOption,
      'repeatDays': repeatDays,
      'repeatCustomDays': repeatCustomDays,
      'isAllDay': isAllDay,
      'reminder': reminder,
      'isReminderScheduled': isReminderScheduled,
      'repeatUntil': repeatUntil,
      'parentEventId': parentEventId,
      'isLongTerm': isLongTerm,
      'term' : term,
    };
  }

  // Firebase에서 불러온 데이터로 Event 생성 (CalendarScreen 코드와 일치하도록 수정)
  factory Event.fromMap(Map<String, dynamic> map, String userId, String docId) {
    try {
      final startDate = (map['startDate'] as Timestamp).toDate();
      final endDate = (map['endDate'] as Timestamp).toDate();
      final repeatUntil = map['repeatUntil'] != null
          ? (map['repeatUntil'] as Timestamp).toDate()
          : null;

      final isAllDay = map['isAllDay'] ?? false;

      // isAllDay가 true면 시간을 null로 설정, 아니면 기존 로직 사용
      final startTime = (!isAllDay && map['startTime'] != null)
          ? TimeOfDay(hour: map['startTime']['hour'] ?? 0, minute: map['startTime']['minute'] ?? 0)
          : null;
      final endTime = (!isAllDay && map['endTime'] != null)
          ? TimeOfDay(hour: map['endTime']['hour'] ?? 0, minute: map['endTime']['minute'] ?? 0)
          : null;

      return Event(
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        userId: map['userId'],
        id: docId,
        title: map['title'] ?? '제목 없음',
        description: map['description'] ?? '',
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        memo: map['memo'] ?? '',
        location: map['location'] ?? '',
        isRepeating: map['isRepeating'] ?? false,
        repeatOption: map['repeatOption'],
        repeatDays: map['repeatDays'] != null ? List<int>.from(map['repeatDays']) : null,
        repeatCustomDays: map['repeatCustomDays'],
        isAllDay: isAllDay,
        reminder: map['reminder'],
        isReminderScheduled: map['isReminderScheduled'] ?? false,
        repeatUntil: repeatUntil,
        parentEventId: map['parentEventId'],
        isLongTerm: map['isLongTerm'] ?? '',
        term: map['term'] ?? 0,
      );
    } catch (e) {
      print('Event.fromMap 오류: $e');
      // 오류 발생 시 기본값으로 Event 반환
      return Event(
        createdAt: DateTime.now(),
        userId: userId,
        id: docId,
        title: '제목 없음',
        description: '',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        startTime: null,
        endTime: null,
        memo: '',
        location: '',
        isRepeating: false,
        isAllDay: true, // 오류 시 안전하게 종일로 설정
        isReminderScheduled: false,
        repeatUntil: null,
        parentEventId: null,
        isLongTerm: '',
        term: 0,
      );
    }
  }

  // Event의 시작 시간을 문자열로 반환하는 메서드 추가 (표시용)
  String getFormattedStartTime(BuildContext context) {
    if (isAllDay) return '종일';
    if (startTime == null) return '';
    return startTime!.format(context);
  }

  // Event의 시작 날짜를 문자열로 반환하는 메서드 추가 (표시용)
  String getFormattedStartDate() {
    return '${startDate.year}/${startDate.month}/${startDate.day}';
  }
}