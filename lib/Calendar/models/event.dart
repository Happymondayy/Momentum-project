import 'package:flutter/material.dart';

class Event {
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

  Event({
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
  });

  // Create a copy of this event with optional modified fields
  Event copyWith({
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
  }) {
    return Event(
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
    );
  }

  // Convert to a map (useful for database storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'startTimeHour': startTime?.hour,
      'startTimeMinute': startTime?.minute,
      'endTimeHour': endTime?.hour,
      'endTimeMinute': endTime?.minute,
      'memo': memo,
      'location': location,
      'isRepeating': isRepeating,
      'repeatOption': repeatOption,
      'repeatDays': repeatDays,
      'repeatCustomDays': repeatCustomDays,
      'isAllDay': isAllDay,
      'reminder': reminder,
    };
  }

  // Create an Event from a map (useful when retrieving from database)
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate']),
      startTime: map['startTimeHour'] != null
          ? TimeOfDay(hour: map['startTimeHour'], minute: map['startTimeMinute'])
          : null,
      endTime: map['endTimeHour'] != null
          ? TimeOfDay(hour: map['endTimeHour'], minute: map['endTimeMinute'])
          : null,
      memo: map['memo'] ?? '',
      location: map['location'] ?? '',
      isRepeating: map['isRepeating'] ?? false,
      repeatOption: map['repeatOption'],
      repeatDays: map['repeatDays'] != null
          ? List<int>.from(map['repeatDays'])
          : null,
      repeatCustomDays: map['repeatCustomDays'],
      isAllDay: map['isAllDay'] ?? false,
      reminder: map['reminder'],
    );
  }
}