import 'package:flutter/material.dart';

class Task {
  String id;
  String title;
  DateTime date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isCompleted;
  String? note;
  int priority; // 1-3 for importance
  int urgency; // 1-3 for urgency
  bool hasNotification;
  String? repeat; // daily, weekly, monthly, etc.
  String? location;

  Task({
    required this.id,
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.note,
    required this.priority,
    required this.urgency,
    this.hasNotification = false,
    this.repeat,
    this.location,
  });
}

class PlannerEvent {
  String id;
  String title;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String? note;
  String? location;
  Color color;

  PlannerEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.note,
    this.location,
    required this.color,
  });
}