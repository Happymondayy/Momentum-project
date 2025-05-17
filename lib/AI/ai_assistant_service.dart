import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:momentum_planner/Calendar/models/event.dart';
import '../Todolist/screens/todo_list_screen.dart';

class AIAssistantService {
  final String userId;

  AIAssistantService({required this.userId});

  // 🔸 시간 포맷
  String _formatTimeOfDay(TimeOfDay? timeOfDay) {
    if (timeOfDay == null) return '';
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final ampm = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  // 🔹 Firestore에서 사용자 목표 불러오기
  Future<List<String>> loadUserGoals() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => doc['goal'] as String).toList();
  }

  // 🔸 목표 저장
  Future<void> saveGoalToFirestore(String goal) async {
    await FirebaseFirestore.instance.collection('goals').add({
      'userId': userId,
      'goal': goal,
      'createdAt': DateTime.now(),
    });
  }

  // 🔹 오늘의 빈 시간대 추천
  List<String> recommendFreeTimeSlots(List<Event> events) {
    final today = DateTime.now();
    final todayEvents = events
        .where((e) => e.startDate.day == today.day && e.startDate.month == today.month)
        .toList()
      ..sort((a, b) => a.startTime!.hour.compareTo(b.startTime!.hour));

    final List<String> freeSlots = [];
    TimeOfDay current = TimeOfDay(hour: 6, minute: 0); // 시작 6AM

    for (var event in todayEvents) {
      if (event.startTime == null || event.endTime == null) continue;

      final start = event.startTime!;
      if (_isBefore(current, start)) {
        freeSlots.add('${_formatTimeOfDay(current)} ~ ${_formatTimeOfDay(start)}');
      }
      current = event.endTime!;
    }

    if (_isBefore(current, TimeOfDay(hour: 22, minute: 0))) {
      freeSlots.add('${_formatTimeOfDay(current)} ~ 10:00 PM');
    }

    return freeSlots;
  }

  bool _isBefore(TimeOfDay a, TimeOfDay b) {
    return a.hour < b.hour || (a.hour == b.hour && a.minute < b.minute);
  }

  // 🔸 Firestore에 AI 추천 일정 저장
  Future<void> saveAIGeneratedScheduleToFirestore(String aiReply) async {
    final RegExp titleRegex = RegExp(r'📌\s*([^\n]+)');
    final RegExp timeRegex = RegExp(r'🕒\s*([^\n]+)');

    final titleMatch = titleRegex.firstMatch(aiReply);
    final timeMatch = timeRegex.firstMatch(aiReply);

    if (titleMatch != null && timeMatch != null) {
      final String title = titleMatch.group(1)!.trim();
      final String time = timeMatch.group(1)!.trim();

      await FirebaseFirestore.instance.collection('events').add({
        'userId': userId,
        'title': title,
        'time': time,
        'createdAt': DateTime.now(),
        'source': 'ai', // 구분용
      });
    }
  }

  // 🔹 Gemini 호출 및 처리
  Future<String> getGeminiSuggestion({
    required String userPrompt,
    required List<Todo_Task> todos,
    required List<Event> calendarEvents,
  }) async {
    final goals = await loadUserGoals();
    final freeSlots = recommendFreeTimeSlots(calendarEvents);

    final String prompt = """
당신은 사용자의 일정과 할 일, 목표를 관리해주는 똑똑한 AI 비서입니다.

[오늘의 일정]
${calendarEvents.isEmpty ? '없음' : calendarEvents.map((e) {
      final start = _formatTimeOfDay(e.startTime);
      final end = _formatTimeOfDay(e.endTime);
      final timeString = (start.isNotEmpty && end.isNotEmpty) ? ' ($start - $end)' : '';
      return "- ${e.title}${timeString}, 위치: ${e.location}";
    }).join('\n')}

[할 일 목록]
${todos.isEmpty ? '없음' : todos.map((e) {
      final timeStr = (e.time != null && e.time!.isNotEmpty) ? ' (${e.time})' : '';
      return "- ${e.title}$timeStr";
    }).join('\n')}

[사용자의 목표]
${goals.isEmpty ? '없음' : goals.map((g) => '- $g').join('\n')}

[추천 가능한 빈 시간대]
${freeSlots.isEmpty ? '없음' : freeSlots.map((slot) => '- $slot').join('\n')}

[사용자 요청]
$userPrompt

요청에 맞는 일정, 목표, 루틴을 구체적으로 제시하고 아래 형식을 사용하세요:

📌 새로운 일정 제목
🕒 추천 시간대 (예: 오후 2시 ~ 3시)
✅ 위 일정을 Firestore에 저장하세요
""";

    final url = Uri.parse('http://192.168.219.110:5001/api/gemini');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode == 200) {
      final reply = jsonDecode(response.body)['reply'] ?? 'AI 응답을 불러오지 못했습니다.';
      await saveAIGeneratedScheduleToFirestore(reply);
      return reply;
    } else {
      return '서버 오류: ${response.statusCode}';
    }
  }
}
