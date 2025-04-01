import 'package:flutter/material.dart';

class Event {
  final String id;
  final String title;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? memo;
  final bool isRepeating;

  Event({
    required this.id,
    required this.title,
    this.startTime,
    this.endTime,
    this.memo,
    this.isRepeating = false,
  });
}