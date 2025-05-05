import 'package:flutter/material.dart';

class TodoItem {
  final String userId;
  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final int importance;
  final int urgency;
  final String memo;
  final String location;
  final bool isRepeating;
  final String? repeatOption;
  final List<int>? repeatDays;
  final int? repeatCustomDays;
  final bool isAllDay;
  final String? reminder;
  final bool isCompleted;

  TodoItem({
    required this.userId,
    required this.id,
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.importance = 3,
    this.urgency = 3,
    this.memo = '',
    this.location = '',
    this.isRepeating = false,
    this.repeatOption,
    this.repeatDays,
    this.repeatCustomDays,
    this.isAllDay = false,
    this.reminder,
    this.isCompleted = false,
  });

  // Create a copy of this event with optional modified fields
  TodoItem copyWith({
    String? userId,
    String? id,
    String? title,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? importance,
    int? urgency,
    String? memo,
    String? location,
    bool? isRepeating,
    String? repeatOption,
    List<int>? repeatDays,
    int? repeatCustomDays,
    bool? isAllDay,
    String? reminder,
    bool? isCompleted,
  }) {
    return TodoItem(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      memo: memo ?? this.memo,
      location: location ?? this.location,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatOption: repeatOption ?? this.repeatOption,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatCustomDays: repeatCustomDays ?? this.repeatCustomDays,
      isAllDay: isAllDay ?? this.isAllDay,
      reminder: reminder ?? this.reminder,
      isCompleted: isCompleted ?? this.isCompleted,
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
      'userId': userId,
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'startTime': startTimeMap,
      'endTime': endTimeMap,
      'important': importance,
      'urgent': urgency,
      'memo': memo,
      'location': location,
      'isRepeating': isRepeating,
      'repeatOption': repeatOption,
      'repeatDays': repeatDays,
      'repeatCustomDays': repeatCustomDays,
      'isAllDay': isAllDay,
      'reminder': reminder,
      'isCompleted': isCompleted,
    };
  }

  // Firebase에서 불러온 데이터로 TosoItem 생성 (CalendarScreen 코드와 일치하도록 수정)
  factory TodoItem.fromMap(Map<String, dynamic> map, String docId) {
    final date = DateTime.parse(map['date']);

    final startTime = map['startTime'] != null
        ? TimeOfDay(hour: map['startTime']['hour'], minute: map['startTime']['minute'])
        : null;
    final endTime = map['endTime'] != null
        ? TimeOfDay(hour: map['endTime']['hour'], minute: map['endTime']['minute'])
        : null;

    return TodoItem(
      userId: map['userId'],
      id: docId,
      title: map['title'],
      date: date,
      startTime: startTime,
      endTime: endTime,
      importance: map['importance'] ?? 3,
      urgency: map['urgency'] ?? 3,
      memo: map['memo'] ?? '',
      location: map['location'] ?? '',
      isRepeating: map['isRepeating'] ?? false,
      repeatOption: map['repeatOption'],
      repeatDays: map['repeatDays'] != null ? List<int>.from(map['repeatDays']) : null,
      repeatCustomDays: map['repeatCustomDays'],
      isAllDay: map['isAllDay'] ?? false,
      reminder: map['reminder'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  // Event의 시작 시간을 문자열로 반환하는 메서드 추가 (표시용)
  String getFormattedStartTime(BuildContext context) {
    if (isAllDay) return '종일';
    if (startTime == null) return '';
    return startTime!.format(context);
  }
}