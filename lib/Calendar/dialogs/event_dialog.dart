import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:momentum_planner/Calendar/models/event.dart';
import 'package:momentum_planner/Calendar/services/notification_service_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class EventDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Function(Event event) onSave;
  final Function(Event, String)? onDelete;
  final Event? event;
  final bool isEditing;
  final String currentUserId;

  const EventDialog({
    Key? key,
    required this.selectedDay,
    required this.onSave,
    this.onDelete,
    this.event,
    this.isEditing = false,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _customReminderController = TextEditingController();
  final TextEditingController _repeatCustomDaysController = TextEditingController();

  // 알림 서비스 인스턴스
  final NotificationServiceCalendar _notificationService = NotificationServiceCalendar();

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0);

  bool _isAllDay = false;
  bool _isRepeating = false;
  String? _repeatOption;
  List<int> _repeatDays = [];
  int? _repeatCustomDays;

  bool _hasReminder = false;
  String? _reminderOption;
  int? _customReminderMinutes;

  bool _titleError = false;
  String? _previousReminder; // 기존 알림 설정 저장 변수

  bool _hasRepeatEnd = false;     // 반복 종료일 설정 여부
  DateTime _repeatUntil = DateTime.now().add(Duration(days: 7)); // 기본 일주일 뒤로 설정


  @override
  void initState() {
    super.initState();

    // 알림 서비스 초기화
    _notificationService.init();

    // Initialize with the existing event data if editing
    if (widget.event != null) {
      _initializeWithEvent(widget.event!);
      // 기존 알림 설정 저장
      _previousReminder = widget.event!.reminder;
    } else {
      // Default values for new event
      _startDate = widget.selectedDay;
      _endDate = widget.selectedDay;
    }

    // Auto focus the title field and show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _initializeWithEvent(Event event) {
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _memoController.text = event.memo ?? '';
    _locationController.text = event.location ?? '';

    _startDate = event.startDate;
    _endDate = event.endDate;

    _isAllDay = event.isAllDay;
    if (!_isAllDay && event.startTime != null) {
      _startTime = event.startTime!;
    }
    if (!_isAllDay && event.endTime != null) {
      _endTime = event.endTime!;
    }

    _isRepeating = event.isRepeating;
    _repeatOption = event.repeatOption;
    _repeatDays = event.repeatDays ?? [];
    _repeatCustomDays = event.repeatCustomDays;

    if (_isRepeating && event.repeatDays != null) {
      _repeatDays = List<int>.from(event.repeatDays!);
    }

    if (_isRepeating && event.repeatCustomDays != null) {
      _repeatCustomDays = event.repeatCustomDays;
      _repeatCustomDaysController.text = event.repeatCustomDays.toString();
    }

    // 알림 설정 로딩 로직 개선
    if (event.reminder != null) {
      _hasReminder = true;

      // 알림 옵션 확인 - 표준 옵션 먼저 검사
      final standardOptions = ['1분 전', '5분 전', '10분 전', '30분 전', '1시간 전'];
      if (standardOptions.contains(event.reminder)) {
        _reminderOption = event.reminder;
        print('표준 알림 옵션 로드됨: $_reminderOption');
      }
      // 커스텀 알림 시간인 경우 (숫자 + "분 전" 형식)
      else if (event.reminder!.endsWith('분 전')) {
        final minutes = event.reminder!.split('분 전')[0].trim();
        if (int.tryParse(minutes) != null) {
          _reminderOption = '기타';
          _customReminderMinutes = int.parse(minutes);
          _customReminderController.text = minutes;
          print('커스텀 알림 옵션 로드됨: $_customReminderMinutes분 전');
        } else {
          // 파싱 실패 시 기본값
          _reminderOption = '10분 전';
          print('알 수 없는 알림 형식, 기본값으로 설정: $_reminderOption');
        }
      } else {
        // 알 수 없는 형식이면 기본값
        _reminderOption = '10분 전';
        print('알 수 없는 알림 형식, 기본값으로 설정: $_reminderOption');
      }
    }

  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    _locationController.dispose();
    _customReminderController.dispose();
    _repeatCustomDaysController.dispose();
    super.dispose();
  }

  // 알림 예약 메서드
  Future<void> _scheduleNotification(Event event) async {
    try {
      if (event.isAllDay == true) {
        return;
      }

      if (event.reminder != null) {
        // 권한 요청
        final status = await Permission.notification.request();
        if (status.isGranted) {
          // 정확한 알림 권한 요청 (Android 12+)
          await _notificationService.requestExactAlarmPermissionIfNeeded();

          // 이벤트 시작 시간 계산
          DateTime eventStartDateTime = DateTime(
            event.startDate.year,
            event.startDate.month,
            event.startDate.day,
            event.startTime!.hour,
            event.startTime!.minute,
          );

          //알림 ID 생성 (이벤트 ID 해시)
          final notificationId = event.id.hashCode.abs();

          print('⏰ 알림 예약: ID=${notificationId}, 이벤트=${event.title}, 시작=${eventStartDateTime}');

          // 알림 예약
          await _notificationService.scheduleReminderNotification(
            id: notificationId,
            title: event.title,
            startDateTime: eventStartDateTime,
            reminder: event.reminder!,
            customMinutes: _customReminderMinutes,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('알림이 설정되었습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('알림 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: '설정',
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('알림 설정 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 설정 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 알림 취소 메서드
  Future<void> _cancelNotification(String eventId) async {
    final notificationId = eventId.hashCode.abs();
    await _notificationService.cancelNotification(notificationId);
    print('🗑️ 알림 취소: ID=${notificationId}');
  }

  void _validateAndSave() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('필수 항목칸을 채워주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    print('=== 일정 저장 시작 ===');

    // 이벤트 ID 생성 또는 기존 ID 유지
    final String eventId = widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    print('이벤트 ID: $eventId');

    final event = Event(
      createdAt: DateTime.now(),
      userId: widget.currentUserId,
      id: eventId,
      title: _titleController.text,
      description: _descriptionController.text,
      startDate: _startDate,
      endDate: _endDate,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      memo: _memoController.text,
      location: _locationController.text,
      isRepeating: _isRepeating,
      repeatOption: _isRepeating ? _repeatOption : null,
      repeatDays: _isRepeating && _repeatOption == '매요일' ? _repeatDays : null,
      repeatCustomDays: _isRepeating && _repeatOption == '기타' ? _repeatCustomDays : null,
      isAllDay: _isAllDay,
      reminder: _getReminderValue(),
      repeatUntil: _isRepeating && _hasRepeatEnd ? _repeatUntil : null,
      parentEventId: widget.event?.parentEventId ?? (_isRepeating ? eventId : null),
      isLongTerm: _startDate != _endDate ? eventId : '',
      term: 0,
    );

    print('Event 객체 생성 완료');
    print('제목: ${event.title}');
    print('시작일: ${event.startDate}');
    print('종료일: ${event.endDate}');
    print('장기일정: ${event.isLongTerm}');
    print('반복: ${event.isRepeating}');

    try {
      print('알림 처리 시작...');
      // 알림 관련 처리
      await _handleNotificationChanges(event);
      print('알림 처리 완료');

      // 장기 일정 처리 (시작날짜와 종료날짜가 다른 경우)
      if (_startDate != _endDate) {
        print('장기 일정 처리 시작...');
        await _handleLongTermEvent(event);
        print('장기 일정 처리 완료');
      }
      // 반복 이벤트 생성 처리
      else if (_isRepeating && !widget.isEditing) {
        print('반복 이벤트 생성 시작...');
        // 새 이벤트 생성 시에만 반복 이벤트 생성
        await _handleRecurringEventCreation(event);
        print('반복 이벤트 생성 완료');
      } else if (_isRepeating && widget.isEditing && widget.event != null) {
        print('반복 이벤트 수정 시작...');
        // 기존 이벤트 수정 시 반복 처리
        await _handleRecurringEventUpdate(event);
        print('반복 이벤트 수정 완료');
      } else {
        print('일반 이벤트 저장 시작...');
        // 반복 아닌 일반 이벤트
        widget.onSave(event);
        print('일반 이벤트 저장 완료');
      }

      print('=== 일정 저장 성공 ===');

      // 다이얼로그 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('=== 일정 저장 오류 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 내용: $e');
      print('스택 트레이스: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 저장 중 오류가 발생했습니다: ${e.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 장기 일정 처리 메소드
  Future<void> _handleLongTermEvent(Event baseEvent) async {
    final List<Event> longTermEvents = [];

    DateTime currentDate = DateTime(
      baseEvent.startDate.year,
      baseEvent.startDate.month,
      baseEvent.startDate.day,
    );

    DateTime endDate = DateTime(
      baseEvent.endDate.year,
      baseEvent.endDate.month,
      baseEvent.endDate.day,
    );

    int dayIndex = 0;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      // 장기 일정의 각 날짜별 이벤트 ID 생성
      final String eventId = widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final Event dailyEvent = Event(
        createdAt: DateTime.now(),
        userId: baseEvent.userId,
        id: eventId,
        title: baseEvent.title,
        description: baseEvent.description,
        startDate: baseEvent.startDate, // 원본 시작일 유지
        endDate: baseEvent.endDate,     // 원본 종료일 유지
        startTime: dayIndex == 0 ? baseEvent.startTime : null, // 첫날만 시작시간
        endTime: currentDate.isAtSameMomentAs(endDate) ? baseEvent.endTime : null, // 마지막날만 종료시간
        memo: baseEvent.memo,
        location: baseEvent.location,
        isRepeating: false,
        repeatOption: null,
        repeatDays: null,
        repeatCustomDays: null,
        isAllDay: baseEvent.isAllDay,
        reminder: dayIndex == 0 ? baseEvent.reminder : null, // 첫날만 알림
        repeatUntil: null,
        parentEventId: baseEvent.parentEventId,
        isLongTerm: baseEvent.id,
        term: dayIndex,
      );

      longTermEvents.add(dailyEvent);

      currentDate = currentDate.add(Duration(days: 1));
      dayIndex++;
    }

    // 모든 장기 일정 이벤트들을 저장
    for (final event in longTermEvents) {
      widget.onSave(event);
    }
  }

  // 반복 이벤트 생성 메서드 수정
  Future<void> _handleRecurringEventCreation(Event baseEvent) async {
    try {
      // 기본 이벤트(첫 번째 일정) 저장
      widget.onSave(baseEvent);
      print('기본 이벤트 저장 완료: ${baseEvent.title}');

      // 반복 이벤트 종료일 설정 (기본 1년)
      final DateTime untilDate = baseEvent.repeatUntil ??
          baseEvent.startDate.add(Duration(days: 365));

      print('반복 옵션: ${baseEvent.repeatOption}, 종료일: $untilDate');

      List<Event> recurringEvents = [];

      switch (baseEvent.repeatOption) {
        case '매일':
          recurringEvents = _createDailyEvents(baseEvent, untilDate);
          break;
        case '매주':
          recurringEvents = _createWeeklyEvents(baseEvent, untilDate);
          break;
        case '매달':
          recurringEvents = _createMonthlyEvents(baseEvent, untilDate);
          break;
        case '매년':
          recurringEvents = _createYearlyEvents(baseEvent, untilDate);
          break;
        case '매요일':
          if (baseEvent.repeatDays != null && baseEvent.repeatDays!.isNotEmpty) {
            recurringEvents = _createWeekdayEvents(baseEvent, untilDate);
          }
          break;
        case '기타':
          if (baseEvent.repeatCustomDays != null && baseEvent.repeatCustomDays! > 0) {
            recurringEvents = _createCustomEvents(baseEvent, untilDate);
          }
          break;
        default:
          print('알 수 없는 반복 옵션: ${baseEvent.repeatOption}');
          break;
      }

      print('생성된 반복 이벤트 수: ${recurringEvents.length}');

      // 반복 이벤트 각각 저장
      for (int i = 0; i < recurringEvents.length; i++) {
        final event = recurringEvents[i];
        widget.onSave(event);
        print('반복 이벤트 ${i + 1} 저장 완료: ${event.startDate}');

        // 알림 등록
        if (event.reminder != null && !event.isAllDay) {
          try {
            await _scheduleNotification(event);
          } catch (e) {
            print('알림 등록 실패: $e');
          }
        }

        // UI 블로킹 방지
        if (i % 10 == 0) {
          await Future.delayed(Duration(milliseconds: 1));
        }
      }

      print('모든 반복 이벤트 생성 완료');
    } catch (e) {
      print('반복 이벤트 생성 중 오류: $e');
      rethrow;
    }
  }

// 매일 반복 이벤트 생성 수정
  List<Event> _createDailyEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      DateTime currentDate = baseEvent.startDate.add(Duration(days: 1));
      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;
      int count = 0;

      while ((currentDate.isBefore(untilDate) || currentDate.isAtSameMomentAs(untilDate)) && count < 365) {
        final newEvent = _createRecurringEventInstance(
          baseEvent: baseEvent,
          startDate: currentDate,
          endDate: currentDate.add(Duration(days: daysDiff)),
          instanceNumber: count + 1,
        );

        events.add(newEvent);
        currentDate = currentDate.add(Duration(days: 1));
        count++;
      }
    } catch (e) {
      print('매일 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 매주 반복 이벤트 생성 수정
  List<Event> _createWeeklyEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      DateTime currentDate = baseEvent.startDate.add(Duration(days: 7));
      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;
      int count = 0;

      while ((currentDate.isBefore(untilDate) || currentDate.isAtSameMomentAs(untilDate)) && count < 52) {
        final newEvent = _createRecurringEventInstance(
          baseEvent: baseEvent,
          startDate: currentDate,
          endDate: currentDate.add(Duration(days: daysDiff)),
          instanceNumber: count + 1,
        );

        events.add(newEvent);
        currentDate = currentDate.add(Duration(days: 7));
        count++;
      }
    } catch (e) {
      print('매주 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 매달 반복 이벤트 생성 수정
  List<Event> _createMonthlyEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      int year = baseEvent.startDate.year;
      int month = baseEvent.startDate.month + 1;
      int day = baseEvent.startDate.day;
      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;
      int count = 0;

      while (count < 12) {
        if (month > 12) {
          year++;
          month = 1;
        }

        // 해당 월의 마지막 날 확인
        int lastDayOfMonth = DateTime(year, month + 1, 0).day;
        int actualDay = day > lastDayOfMonth ? lastDayOfMonth : day;

        DateTime currentDate = DateTime(year, month, actualDay);

        if (currentDate.isAfter(untilDate)) break;

        final newEvent = _createRecurringEventInstance(
          baseEvent: baseEvent,
          startDate: currentDate,
          endDate: currentDate.add(Duration(days: daysDiff)),
          instanceNumber: count + 1,
        );

        events.add(newEvent);
        month++;
        count++;
      }
    } catch (e) {
      print('매달 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 매년 반복 이벤트 생성 수정
  List<Event> _createYearlyEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      DateTime currentDate = DateTime(
        baseEvent.startDate.year + 1,
        baseEvent.startDate.month,
        baseEvent.startDate.day,
      );

      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;
      int count = 0;

      while ((currentDate.isBefore(untilDate) || currentDate.isAtSameMomentAs(untilDate)) && count < 10) {
        final newEvent = _createRecurringEventInstance(
          baseEvent: baseEvent,
          startDate: currentDate,
          endDate: currentDate.add(Duration(days: daysDiff)),
          instanceNumber: count + 1,
        );

        events.add(newEvent);
        currentDate = DateTime(
          currentDate.year + 1,
          baseEvent.startDate.month,
          baseEvent.startDate.day,
        );
        count++;
      }
    } catch (e) {
      print('매년 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 매요일 반복 이벤트 생성 수정
  List<Event> _createWeekdayEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      final List<int> selectedDays = List<int>.from(baseEvent.repeatDays!)..sort();
      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;

      DateTime currentDate = baseEvent.startDate.add(Duration(days: 1));
      int count = 0;

      while ((currentDate.isBefore(untilDate) || currentDate.isAtSameMomentAs(untilDate)) && count < 365) {
        // 요일 계산 (월요일=1, 일요일=7 -> 월요일=0, 일요일=6으로 변환)
        int weekday = (currentDate.weekday - 1) % 7;

        if (selectedDays.contains(weekday)) {
          final newEvent = _createRecurringEventInstance(
            baseEvent: baseEvent,
            startDate: currentDate,
            endDate: currentDate.add(Duration(days: daysDiff)),
            instanceNumber: events.length + 1,
          );

          events.add(newEvent);
        }

        currentDate = currentDate.add(Duration(days: 1));
        count++;
      }
    } catch (e) {
      print('매요일 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 사용자 지정 반복 이벤트 생성 수정
  List<Event> _createCustomEvents(Event baseEvent, DateTime untilDate) {
    List<Event> events = [];

    try {
      final int repeatInterval = baseEvent.repeatCustomDays!;
      if (repeatInterval <= 0) return events;

      int daysDiff = baseEvent.endDate.difference(baseEvent.startDate).inDays;
      DateTime currentDate = baseEvent.startDate.add(Duration(days: repeatInterval));
      int count = 0;

      while ((currentDate.isBefore(untilDate) || currentDate.isAtSameMomentAs(untilDate)) && count < 100) {
        final newEvent = _createRecurringEventInstance(
          baseEvent: baseEvent,
          startDate: currentDate,
          endDate: currentDate.add(Duration(days: daysDiff)),
          instanceNumber: count + 1,
        );

        events.add(newEvent);
        currentDate = currentDate.add(Duration(days: repeatInterval));
        count++;
      }
    } catch (e) {
      print('사용자 지정 반복 이벤트 생성 오류: $e');
    }

    return events;
  }

// 반복 이벤트 인스턴스 생성 헬퍼 메서드 수정
  Event _createRecurringEventInstance({
    required Event baseEvent,
    required DateTime startDate,
    required DateTime endDate,
    required int instanceNumber,
  }) {
    // 더 안전한 ID 생성
    final String newId = '${baseEvent.id}_${instanceNumber}_${startDate.millisecondsSinceEpoch}';

    return Event(
      createdAt: DateTime.now(),
      userId: baseEvent.userId,
      id: newId,
      title: baseEvent.title,
      description: baseEvent.description,
      startDate: startDate,
      endDate: endDate,
      startTime: baseEvent.startTime,
      endTime: baseEvent.endTime,
      memo: baseEvent.memo,
      location: baseEvent.location,
      isRepeating: true,
      repeatOption: baseEvent.repeatOption,
      repeatDays: baseEvent.repeatDays,
      repeatCustomDays: baseEvent.repeatCustomDays,
      isAllDay: baseEvent.isAllDay,
      reminder: baseEvent.reminder,
      repeatUntil: baseEvent.repeatUntil,
      parentEventId: baseEvent.id,
      isLongTerm: baseEvent.isLongTerm,
      term: baseEvent.term,
    );
  }



 // 반복 이벤트 수정 메서드 수정
  Future<void> _handleRecurringEventUpdate(Event updatedEvent) async {
    try {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFFF5F5F5),
            title: Text('반복 일정 수정'),
            content: Text('어떤 일정을 수정하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('this'),
                child: Text('이 일정만'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('thisAndFuture'),
                child: Text('이 일정 및 향후 일정'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('all'),
                child: Text('모든 반복 일정'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('취소'),
              ),
            ],
          );
        },
      );

      if (choice == null) return;

      switch (choice) {
        case 'this':
          await _updateSingleEvent(updatedEvent);
          break;
        case 'thisAndFuture':
          await _updateThisAndFutureEvents(updatedEvent);
          break;
        case 'all':
          await _updateAllRecurringEvents(updatedEvent);
          break;
      }
    } catch (e) {
      print('반복 이벤트 수정 중 오류: $e');
      rethrow;
    }
  }

// 단일 이벤트 수정
  Future<void> _updateSingleEvent(Event updatedEvent) async {
    widget.onSave(updatedEvent);
  }

// 이 일정 및 향후 일정 수정
  Future<void> _updateThisAndFutureEvents(Event updatedEvent) async {
    try {
      // 현재 이벤트 수정
      widget.onSave(updatedEvent);

      final String? parentId = updatedEvent.parentEventId ?? updatedEvent.id;
      if (parentId == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('parentEventId', isEqualTo: parentId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final Timestamp startTimestamp = data['startDate'] as Timestamp;
        final DateTime startDate = startTimestamp.toDate();
        final Timestamp endTimestamp = data['endDate'] as Timestamp;
        final DateTime endDate = endTimestamp.toDate();

        if (!startDate.isBefore(updatedEvent.startDate)) {
          final Event eventToUpdate = Event(
            createdAt: updatedEvent.createdAt,
            userId: updatedEvent.userId,
            id: doc.id,
            title: updatedEvent.title,
            description: updatedEvent.description,
            startDate: startDate,
            endDate: endDate,
            startTime: updatedEvent.startTime,
            endTime: updatedEvent.endTime,
            memo: updatedEvent.memo,
            location: updatedEvent.location,
            isRepeating: updatedEvent.isRepeating,
            repeatOption: updatedEvent.repeatOption,
            repeatDays: updatedEvent.repeatDays,
            repeatCustomDays: updatedEvent.repeatCustomDays,
            isAllDay: updatedEvent.isAllDay,
            reminder: updatedEvent.reminder,
            repeatUntil: updatedEvent.repeatUntil,
            parentEventId: updatedEvent.parentEventId,
            isLongTerm: updatedEvent.isLongTerm,
            term: updatedEvent.term,
          );
          widget.onSave(eventToUpdate);
        }
      }
    } catch (e) {
      print('향후 일정 수정 중 오류: $e');
      rethrow;
    }
  }

  // 모든 반복 일정 수정
  Future<void> _updateAllRecurringEvents(Event updatedEvent) async {
    try {
      final String? parentId = updatedEvent.parentEventId ?? updatedEvent.id;
      if (parentId == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('parentEventId', isEqualTo: parentId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final Timestamp startTimestamp = data['startDate'] as Timestamp;
        final DateTime startDate = startTimestamp.toDate();
        final Timestamp endTimestamp = data['endDate'] as Timestamp;
        final DateTime endDate = endTimestamp.toDate();

        final Event eventToUpdate = Event(
          createdAt: updatedEvent.createdAt,
          userId: updatedEvent.userId,
          id: doc.id,
          title: updatedEvent.title,
          description: updatedEvent.description,
          startDate: startDate,
          endDate: endDate,
          startTime: updatedEvent.startTime,
          endTime: updatedEvent.endTime,
          memo: updatedEvent.memo,
          location: updatedEvent.location,
          isRepeating: updatedEvent.isRepeating,
          repeatOption: updatedEvent.repeatOption,
          repeatDays: updatedEvent.repeatDays,
          repeatCustomDays: updatedEvent.repeatCustomDays,
          isAllDay: updatedEvent.isAllDay,
          reminder: updatedEvent.reminder,
          repeatUntil: updatedEvent.repeatUntil,
          parentEventId: updatedEvent.parentEventId,
          isLongTerm: updatedEvent.isLongTerm,
          term: updatedEvent.term,
        );
        widget.onSave(eventToUpdate);
      }
    } catch (e) {
      print('모든 반복 일정 수정 중 오류: $e');
      rethrow;
    }
  }

  //단일 일정 삭제 메서드
  Future<void> _performDelete() async {
    if (widget.onDelete == null || widget.event == null) {
      // 삭제할 수 없는 경우 메인 다이얼로그만 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }
    await widget.onDelete!(widget.event!, 'single');
  }

  // 알림 설정 변경 처리 메서드
  Future<void> _handleNotificationChanges(Event newEvent) async {
    // 기존 이벤트가 있는 경우
    if (widget.isEditing && widget.event != null) {
      // 기존에 알림이 있었는데 없어진 경우 또는 변경된 경우
      if (_previousReminder != null) {
        // 알림 취소
        await _cancelNotification(widget.event!.id);
      }
    }

    // 새 알림 설정이 있는 경우 예약
    if (newEvent.reminder != null) {
      await _scheduleNotification(newEvent);
    }
  }

  void _deleteEvent() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Color(0xFFF5F5F5),
          title: Text('일정 삭제', style: TextStyle(fontSize: 22),),
          content: Text('이 일정을 삭제하시겠습니까?'),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // 확인 다이얼로그만 닫기
                  },
                  child: Text('취소', style: TextStyle(color: Colors.grey[700])),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop(); // 확인 다이얼로그 먼저 닫기
                    // 단일 일정 삭제 작업 수행
                    await _performDelete();
                  },
                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        );
      },
    );
  }


  String _getFormattedTimeWithAmPm(TimeOfDay time) {
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    final int hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    return '$period ${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getFormattedDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('날짜', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        InkWell(
          onTap: () async {
            try {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.blue, // 선택된 날짜 동그라미 색상
                        onPrimary: Colors.white, // 선택된 날짜 텍스트 색상
                        surface: Colors.white, // 배경색
                        onSurface: Colors.black, // 일반 텍스트 색상
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                setState(() {
                  _startDate = pickedDate;
                  if (_endDate.isBefore(_startDate)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('종료 날짜가 시작 날짜보다 이전입니다.')),
                    );
                    _endDate = _startDate;
                  }
                });
              }
            } catch (e) {
              print('시작 날짜 선택 중 오류 발생: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('날짜 선택 중 오류가 발생했습니다.')),
              );
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white, // 회색에서 흰색으로 변경
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getFormattedDate(_startDate),
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        Text('~', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        SizedBox(height: 10),
        InkWell(
          onTap: () async {
            try {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _endDate,
                firstDate: _startDate, // 시작일보다 전의 날짜는 선택할 수 없도록
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.blue, // 선택된 날짜 동그라미 색상
                        onPrimary: Colors.white, // 선택된 날짜 텍스트 색상
                        surface: Colors.white, // 배경색
                        onSurface: Colors.black, // 일반 텍스트 색상
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                setState(() {
                  _endDate = pickedDate;
                });
              }
            } catch (e) {
              print('종료 날짜 선택 중 오류 발생: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('날짜 선택 중 오류가 발생했습니다.')),
              );
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white, // 회색에서 흰색으로 변경
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getFormattedDate(_endDate),
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('하루종일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Switch(
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                });
              },
              activeColor: Colors.deepPurple[300],
            ),
          ],
        ),
        if (!_isAllDay) ...[
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() {
                        _startTime = time;
                        // 시작 시간이 종료 시간보다 늦다면 종료 시간을 1시간 뒤로 설정
                        if (_isSameDay() && _isTimeAfter(_startTime, _endTime)) {
                          final int hour = (_startTime.hour + 1) % 24;
                          _endTime = TimeOfDay(hour: hour, minute: _startTime.minute);
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getFormattedTimeWithAmPm(_startTime),
                          style: TextStyle(fontSize: 16),
                        ),
                        Icon(Icons.access_time, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 15),
              Text('~', style: TextStyle(fontSize: 16)),
              SizedBox(width: 15),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() {
                        _endTime = time;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getFormattedTimeWithAmPm(_endTime),
                          style: TextStyle(fontSize: 16),
                        ),
                        Icon(Icons.access_time, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 같은 날짜인지 확인하는 헬퍼 메서드
  bool _isSameDay() {
    return _startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day;
  }

  // 시작 시간이 종료 시간보다 이후인지 확인하는 헬퍼 메서드
  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    return time1.hour > time2.hour ||
        (time1.hour == time2.hour && time1.minute >= time2.minute);
  }

  Widget _buildReminderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('미리 알림', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Switch(
              value: _hasReminder,
              onChanged: (value) {
                setState(() {
                  _hasReminder = value;
                  if (value && _reminderOption == null) {
                    _reminderOption = '10분 전'; // 기본값 설정
                  }
                });
              },
              activeColor: Colors.deepPurple[300],
            ),
          ],
        ),
        if (_hasReminder) ...[
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _reminderOption,
                hint: Text('알림 시간 선택'),
                items: [
                  DropdownMenuItem(value: '1분 전', child: Text('1분 전')),
                  DropdownMenuItem(value: '5분 전', child: Text('5분 전')),
                  DropdownMenuItem(value: '10분 전', child: Text('10분 전')),
                  DropdownMenuItem(value: '30분 전', child: Text('30분 전')),
                  DropdownMenuItem(value: '1시간 전', child: Text('1시간 전')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _reminderOption = value;
                  });
                },
              ),
            ),
          ),
          if (_reminderOption == '기타') ...[
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _customReminderController,
                      decoration: InputDecoration(
                        hintText: '시간(분)',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _customReminderMinutes = int.tryParse(value);
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text('분 전', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRepeatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('반복', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Switch(
              value: _isRepeating,
              onChanged: (value) {
                setState(() {
                  _isRepeating = value;
                  if (value && _repeatOption == null) {
                    _repeatOption = '매일'; // 기본값 설정
                  }
                });
              },
              activeColor: Colors.deepPurple[300],
            ),
          ],
        ),
        if (_isRepeating) ...[
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _repeatOption,
                hint: Text('반복 주기 선택'),
                items: [
                  DropdownMenuItem(value: '매일', child: Text('매일')),
                  DropdownMenuItem(value: '매주', child: Text('매주')),
                  DropdownMenuItem(value: '매달', child: Text('매달')),
                  DropdownMenuItem(value: '매년', child: Text('매년')),
                  DropdownMenuItem(value: '매요일', child: Text('매요일')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _repeatOption = value;
                    if (value == '매요일' && _repeatDays.isEmpty) {
                      // 처음 매요일을 선택했을 때 현재 요일을 기본으로 선택
                      final now = DateTime.now();
                      int weekday = now.weekday - 1; // 0-6으로 변환 (월-일)
                      _repeatDays = [weekday];
                    }
                  });
                },
              ),
            ),
          ),

          // 반복 종료일 설정
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('반복 종료 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Switch(
                value: _hasRepeatEnd,
                onChanged: (value) {
                  setState(() {
                    _hasRepeatEnd = value;
                    if (value && _repeatUntil.isBefore(_startDate)) {
                      // 종료일이 시작일보다 이전이면 기본값으로 한 달 뒤로 설정
                      _repeatUntil = _startDate.add(Duration(days: 30));
                    }
                  });
                },
                activeColor: Colors.deepPurple[300],
              ),
            ],
          ),

          if (_hasRepeatEnd) ...[
            SizedBox(height: 10),
            InkWell(
              onTap: () async {
                try {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _repeatUntil,
                    firstDate: _startDate,
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _repeatUntil = pickedDate;
                    });
                  }
                } catch (e) {
                  print('반복 종료일 선택 중 오류 발생: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('날짜 선택 중 오류가 발생했습니다.')),
                    );
                  }
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getFormattedDate(_repeatUntil),
                      style: TextStyle(fontSize: 16),
                    ),
                    Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 5),
            Text(
              '해당 날짜까지 반복됩니다',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],

          if (_repeatOption == '매요일') ...[
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(['월', '화', '수', '목', '금', '토', '일'][i]),
                    selected: _repeatDays.contains(i),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _repeatDays.add(i);
                        } else {
                          // 적어도 하나의 요일은 선택되어 있어야 함
                          if (_repeatDays.length > 1) {
                            _repeatDays.remove(i);
                          } else {
                            // 사용자에게 알림
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('적어도 하나의 요일을 선택해야 합니다'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.deepPurple[100],
                    checkmarkColor: Colors.deepPurple,
                  ),
              ],
            ),
          ] else if (_repeatOption == '기타') ...[
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _repeatCustomDaysController,
                      decoration: InputDecoration(
                        hintText: '날짜 간격',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _repeatCustomDays = int.tryParse(value);
                      },
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text('일마다', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ],
      ],
    );
  }

  String? _getReminderValue() {
    if (!_hasReminder) return null;
    if (_reminderOption == '기타' && _customReminderMinutes != null) {
      return '$_customReminderMinutes분 전';
    }
    return _reminderOption;
  }

  @override
  Widget build(BuildContext context) {
    final String dialogTitle = widget.isEditing ? '일정 상세' : '새 일정 추가';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed app bar with close button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    dialogTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Empty container for balanced spacing
                  Container(width: 48),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[300]),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: '제목',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                errorText: _titleError ? '제목을 입력해주세요' : null,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              style: TextStyle(fontSize: 18),
                              autofocus: true,
                              onChanged: (_) => setState(() {
                                _titleError = false;
                              }),
                            ),
                          ),
                          // 필수 표시 (빨간 별표 등)
                          if (_titleError)
                            Icon(Icons.error_outline, color: Colors.red, size: 18)
                          else
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      Divider(color: _titleError ? Colors.red : Colors.grey[300]),
                      SizedBox(height: 10),

                      // Description field
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: '간단한 내용',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: TextStyle(fontSize: 16),
                      ),
                      Divider(color: Colors.grey[300]),
                      SizedBox(height: 20),

                      // Date selector
                      _buildDateSelector(),
                      SizedBox(height: 20),

                      // Time selector
                      _buildTimeSelector(),
                      SizedBox(height: 20),

                      // Reminder selector
                      _buildReminderSelector(),
                      SizedBox(height: 20),

                      // Repeat selector
                      _buildRepeatSelector(),
                      SizedBox(height: 20),

                      // Memo field
                      Text('메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: _memoController,
                          decoration: InputDecoration(
                            hintText: '메모',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Location field
                      Text('위치', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            hintText: '위치',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 30),

                      // Save button
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.isEditing && widget.onDelete != null) ...[
                              Expanded(child: ElevatedButton(
                              onPressed: _deleteEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                '삭제',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              )
                              )
                             ],
                            SizedBox(width: 16,),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _validateAndSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple[300],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  '저장',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color getRandomColor(String seed) {
    final hash = seed.hashCode;
    final random = Random(hash);
    return Color.fromARGB(
      255,
      100 + random.nextInt(156), // R: 100~255
      100 + random.nextInt(156), // G: 100~255
      100 + random.nextInt(156), // B: 100~255
    );
  }
}