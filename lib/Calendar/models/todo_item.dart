import 'package:flutter/material.dart';

class TodoItem {
  final String id;
  final String title;
  final TimeOfDay? time;
  final String? memo;
  final bool isRepeating;
  final bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.time,
    this.memo,
    this.isRepeating = false,
    this.isCompleted = false,
  });
}