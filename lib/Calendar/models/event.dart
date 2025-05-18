import 'package:flutter/material.dart';

class Event {
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

  Event({
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
  });

  // Create a copy of this event with optional modified fields
  Event copyWith({
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
  }) {
    return Event(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      memo: memo ?? this.memo,
      location: location ?? this.location,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatOption: repeatOption ?? this.repeatOption,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatCustomDays: repeatCustomDays ?? this.repeatCustomDays,
      isAllDay: isAllDay ?? this.isAllDay,
      reminder: reminder ?? this.reminder,
      isReminderScheduled: isReminderScheduled ?? this.isReminderScheduled,

    );
  }

  // Firebase에 저장하기 위한 Map 변환 메서드 (CalendarScreen 코드와 일치하도록 수정)
  Map<String, dynamic> toMap() {
    final startTimeMap = !isAllDay && startTime != null ? {
      'hour': startTime!.hour,
      'minute': startTime!.minute,
    } : null;

    final endTimeMap = !isAllDay && endTime != null ? {
      'hour': endTime!.hour,
      'minute': endTime!.minute,
    } : null;

    return {
      'userId' : userId,
      'id' : id,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
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
    };
  }

  // Firebase에서 불러온 데이터로 Event 생성 (CalendarScreen 코드와 일치하도록 수정)
  factory Event.fromMap(Map<String, dynamic> map, String userId, String docId) {
    final startDate = DateTime.parse(map['startDate']);
    final endDate = DateTime.parse(map['endDate']);

    final startTime = map['startTime'] != null
        ? TimeOfDay(hour: map['startTime']['hour'], minute: map['startTime']['minute'])
        : null;
    final endTime = map['endTime'] != null
        ? TimeOfDay(hour: map['endTime']['hour'], minute: map['endTime']['minute'])
        : null;

    return Event(
      userId: map['userId'],
      id: docId,
      title: map['title'],
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
      isAllDay: map['isAllDay'] ?? false,
      reminder: map['reminder'],
      isReminderScheduled: map['isReminderScheduled'] ?? false,
    );
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