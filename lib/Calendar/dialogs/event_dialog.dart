import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:momentum_planner/Calendar/models/event.dart';
import 'package:momentum_planner/Calendar/services/notification_service_calendar.dart';
import 'package:permission_handler/permission_handler.dart';

class EventDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Function(Event event) onSave;
  final Function(Event event)? onDelete;
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

  // Check if required fields are filled
  bool get _isFormValid => _titleController.text.trim().isNotEmpty;

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

          // 안전한 알림 ID 생성 (이벤트 ID 해시)
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

  // _validateAndSave 메소드 수정
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

    final event = Event(
      userId: widget.currentUserId,
      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
    );

    try {
      // 알림 관련 처리
      await _handleNotificationChanges(event);

      // Call the onSave callback with the event object
      widget.onSave(event);

      // 약간의 지연 후 다이얼로그 닫기
      await Future.delayed(Duration(milliseconds: 100));

      // 다이얼로그 닫기 (추가 안전 장치)
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('일정 저장 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 저장 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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

// _deleteEvent() 메서드 수정
  void _deleteEvent() {
    // 삭제 전 확인 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('일정 삭제'),
          content: Text('이 일정을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 확인 다이얼로그만 닫기
              },
              child: Text('취소', style: TextStyle(color: Colors.grey[700])),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // 확인 다이얼로그 먼저 닫기

                // 삭제 작업 수행
                await _performDelete();
              },
              child: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 실제 삭제 작업을 수행하는 수정된 메서드
  Future<void> _performDelete() async {
    if (widget.onDelete == null || widget.event == null) {
      // 삭제할 수 없는 경우 메인 다이얼로그만 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      // 알림 취소
      if (widget.event!.reminder != null) {
        await _cancelNotification(widget.event!.id);
      }

      // 삭제 콜백 호출 - 이 부분에서 실제 Firestore 삭제가 일어남
      widget.onDelete!(widget.event!);

      // 삭제 작업 완료 후 잠시 대기
      await Future.delayed(Duration(milliseconds: 200));

      // Navigator를 root로 확실히 돌아가기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

    } catch (e) {
      print('이벤트 삭제 중 오류 발생: $e');

      if (mounted) {
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 삭제 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        // 오류가 발생해도 다이얼로그는 닫기
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
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
                            ElevatedButton(

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
                            if (widget.isEditing && widget.onDelete != null) ...[
                              SizedBox(width: 15),
                              ElevatedButton(
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

                              ),
                            ],
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
}