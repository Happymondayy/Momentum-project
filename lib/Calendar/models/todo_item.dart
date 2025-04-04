import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TodoItem {
  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay? time; // time을 선택적 인자로 변경
  final String memo;
  final String location;
  final bool isRepeating;
  final String? repeatOption;
  final List<int>? repeatDays;
  final int? repeatCustomDays;
  final String? reminder;
  bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    required this.date,
    this.time, // 선택적 인자
    this.memo = '',
    this.location = '',
    this.isRepeating = false,
    this.repeatOption,
    this.repeatDays,
    this.repeatCustomDays,
    this.reminder,
    this.isCompleted = false,
  });
}