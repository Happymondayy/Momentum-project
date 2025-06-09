import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:momentum_planner/Calendar/models/todo_item.dart';
import 'package:momentum_planner/Calendar/services/notification_service_todolist.dart';
import 'package:permission_handler/permission_handler.dart';

class TodoDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Function(TodoItem todo) onSave;
  final Function(TodoItem todo)? onDelete;
  final TodoItem? todo;
  final bool isEditing;
  final String currentUserId;

  const TodoDialog({
    Key? key,
    required this.selectedDay,
    required this.onSave,
    this.onDelete,
    this.todo,
    this.isEditing = false,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _TodoDialogState createState() => _TodoDialogState();
}

class _TodoDialogState extends State<TodoDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _customReminderController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _repeatCustomDaysController = TextEditingController();

  // 알림 서비스 인스턴스
  final NotificationServiceTodolist _notificationService = NotificationServiceTodolist();

  late DateTime _date;
  DateTime? _dueDate; // 마감일 추가
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  int _importance = 3;
  int _urgency = 3;

  bool _hasReminder = false;
  String? _reminderOption;
  int? _customReminderMinutes;

  bool _isAllDay = false;
  bool _isRepeating = false;
  String? _repeatOption;
  List<int> _repeatDays = [];
  int? _repeatCustomDays;
  bool _isCompleted = false;

  bool _titleError = false;
  String? _previousReminder; // 기존 알림 설정 저장 변수

  // Check if required fields are filled
  bool get _isFormValid =>
      _titleController.text
          .trim()
          .isNotEmpty;

  @override
  void initState() {
    super.initState();

    // 알림 서비스 초기화
    _notificationService.init();

    if (widget.todo != null) {
      _initializeWithTodo(widget.todo!);
    } else {
      _date = widget.selectedDay;
      // 기본 시간 값 확실히 설정
      _startTime = null;
      _endTime = null;
    }

    // Auto focus the title field and show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _initializeWithTodo(TodoItem todo) {
    _titleController.text = todo.title;
    _memoController.text = todo.memo ?? '';
    _locationController.text = todo.location ?? '';
    _date = todo.date;
    _dueDate = todo.dueDate; // 마감일 초기화
    _importance = todo.importance;
    _urgency = todo.urgency;
    _isCompleted = todo.isCompleted;

    _isAllDay = todo.isAllDay;

    // 시간 초기화 - null 체크와 기본값 설정
    if (!_isAllDay) {
      _startTime = todo.startTime;
      _endTime = todo.endTime;
    } else {
      _startTime = null;
      _endTime = null;
    }

    _isRepeating = todo.isRepeating;
    _repeatOption = todo.repeatOption;

    if (_isRepeating && todo.repeatDays != null) {
      _repeatDays = List<int>.from(todo.repeatDays!);
    }

    if (_isRepeating && todo.repeatCustomDays != null) {
      _repeatCustomDays = todo.repeatCustomDays;
      _repeatCustomDaysController.text = todo.repeatCustomDays.toString();
    }

    // 알림 설정 로딩 로직 개선
    if (todo.reminder != null) {
      _hasReminder = true;
      _previousReminder = todo.reminder; // 기존 알림 설정 저장

      // 알림 옵션 확인 - 표준 옵션 먼저 검사
      final standardOptions = ['1분 전', '5분 전', '10분 전', '30분 전', '1시간 전'];
      if (standardOptions.contains(todo.reminder)) {
        _reminderOption = todo.reminder;
        print('표준 알림 옵션 로드됨: $_reminderOption');
      }
      // 커스텀 알림 시간인 경우 (숫자 + "분 전" 형식)
      else if (todo.reminder!.endsWith('분 전')) {
        final minutes = todo.reminder!.split('분 전')[0].trim();
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
    _memoController.dispose();
    _locationController.dispose();
    _customReminderController.dispose();
    _repeatCustomDaysController.dispose();
    super.dispose();
  }

  // 알림 예약 메서드
  Future<void> _scheduleNotification(TodoItem todo) async {
    try {
      if (todo.isAllDay == true) {
        return;
      }

      if (todo.reminder != null) {
        // 권한 요청
        final status = await Permission.notification.request();
        if (status.isGranted) {
          // 정확한 알림 권한 요청 (Android 12+)
          await _notificationService.requestExactAlarmPermissionIfNeeded();

          // 이벤트 시작 시간 계산
          DateTime todoStartDateTime = DateTime(
            todo.date.year,
            todo.date.month,
            todo.date.day,
            todo.startTime!.hour,
            todo.startTime!.minute,
          );

          // 안전한 알림 ID 생성 (todo ID 해시)
          final notificationId = todo.id.hashCode.abs();

          print('⏰ 알림 예약: ID=${notificationId}, 이벤트=${todo
              .title}, 시작=${todoStartDateTime}');

          // 알림 예약
          await _notificationService.scheduleReminderNotification(
            id: notificationId,
            title: todo.title,
            startDateTime: todoStartDateTime,
            reminder: todo.reminder!,
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
  Future<void> _cancelNotification(String todoId) async {
    final notificationId = todoId.hashCode.abs();
    await _notificationService.cancelNotification(notificationId);
    print('🗑️ 알림 취소: ID=${notificationId}');
  }

  void _validateAndSave() async {
    if (_titleController.text
        .trim()
        .isEmpty) {
      setState(() {
        _titleError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필수 항목칸을 채워주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final todo = TodoItem(
      userId: widget.currentUserId,
      id: widget.todo?.id ?? DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(),
      // Use existing ID if editing
      title: _titleController.text,
      date: _date,
      dueDate: _dueDate,
      // 마감일 추가
      importance: _importance,
      urgency: _urgency,
      memo: _memoController.text.isNotEmpty ? _memoController.text : '',
      location: _locationController.text.isNotEmpty
          ? _locationController.text
          : '',
      startTime: _startTime,
      endTime: _endTime,
      isRepeating: _isRepeating,
      repeatOption: _isRepeating ? _repeatOption : null,
      repeatDays: _isRepeating && _repeatOption == '매요일' ? _repeatDays : null,
      repeatCustomDays: _isRepeating && _repeatOption == '기타'
          ? _repeatCustomDays
          : null,
      isAllDay: _isAllDay,
      reminder: _getReminderValue(),
      isCompleted: _isCompleted,
    );

    try {
      // 알림 관련 처리
      await _handleNotificationChanges(todo);

      // Call the onSave callback with the event object
      widget.onSave(todo);

      // 약간의 지연 후 다이얼로그 닫기
      await Future.delayed(Duration(milliseconds: 100));

      // 다이얼로그 닫기 (mounted 확인)
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Todo 저장 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todo 저장 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 알림 설정 변경 처리 메서드
  Future<void> _handleNotificationChanges(TodoItem newTodo) async {
    // 기존 이벤트가 있는 경우
    if (widget.isEditing && widget.todo != null) {
      // 기존에 알림이 있었는데 없어진 경우 또는 변경된 경우
      if (_previousReminder != null) {
        // 알림 취소
        await _cancelNotification(widget.todo!.id);
      }
    }

    // 새 알림 설정이 있는 경우 예약
    if (newTodo.reminder != null) {
      await _scheduleNotification(newTodo);
    }
  }

  String _getFormattedTimeWithAmPm(TimeOfDay time) {
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    final int hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0
        ? 12
        : time.hour);
    return '$period ${hour.toString().padLeft(2, '0')}:${time.minute
        .toString()
        .padLeft(2, '0')}';
  }

  String _getFormattedDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Check if dates are the same day
  bool _isSameDay() {
    return true; // Assuming we're working with a single day
  }

  // 삭제 함수 추가
  void _deleteTodo() {
    // 삭제 전 확인 다이얼로그 표시
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Todo 삭제'),
          content: Text('이 Todo를 삭제하시겠습니까?'),
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
    if (widget.onDelete == null || widget.todo == null) {
      // 삭제할 수 없는 경우 메인 다이얼로그만 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      // 알림 취소
      if (widget.todo!.reminder != null) {
        await _cancelNotification(widget.todo!.id);
      }

      // 삭제 콜백 호출 - 이 부분에서 실제 Firestore 삭제가 일어남
      widget.onDelete!(widget.todo!);

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

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '날짜',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setState(() {
                  _date = pickedDate;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getFormattedDate(_date),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF5F6368)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '마감일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? _date.add(Duration(days: 1)),
                firstDate: _date, // 작업 날짜보다 이전은 선택할 수 없음
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setState(() {
                  _dueDate = pickedDate;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dueDate != null
                        ? _getFormattedDate(_dueDate!)
                        : '마감일을 선택하세요 (선택사항)',
                    style: TextStyle(
                      fontSize: 16,
                      color: _dueDate != null ? Colors.black : Color(0xFF9AA0A6),
                    ),
                  ),
                  Row(
                    children: [
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                          child: Icon(Icons.clear, size: 20, color: Colors.grey),
                        ),
                      SizedBox(width: 8),
                      Icon(Icons.calendar_today, size: 20, color: Color(0xFF5F6368)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildImportanceSelector({
    required int importance,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            '중요도',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Slider(
                      value: importance.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _getImportanceLabel(importance),
                      onChanged: (value) => onChanged(value.round()),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('높음'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  5,
                      (index) =>
                      GestureDetector(
                        onTap: () => onChanged(index + 1),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: importance == index + 1
                                ? _getImportanceColor(index + 1)
                                : Colors.transparent,
                            border: Border.all(
                              color: _getImportanceColor(index + 1),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: importance == index + 1
                                    ? Colors.white
                                    : _getImportanceColor(index + 1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '현재 중요도: ${_getImportanceLabel(importance)}',
                style: TextStyle(
                  color: _getImportanceColor(importance),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(BuildContext context,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      Function(TimeOfDay?, TimeOfDay?) onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시간 설정 (선택사항)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildOptionalTimePicker(
                context,
                startTime,
                '시작 시간',
                    (time) => onTimeChanged(time, endTime),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOptionalTimePicker(
                context,
                endTime,
                '종료 시간',
                    (time) => onTimeChanged(startTime, time),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildUrgencySelector({
    required int urgency,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0, top: 16.0),
          child: Text(
            '긴급도',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('낮음'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Slider(
                      value: urgency.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _getUrgencyLabel(urgency),
                      onChanged: (value) => onChanged(value.round()),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('높음'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  5,
                      (index) =>
                      GestureDetector(
                        onTap: () => onChanged(index + 1),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: urgency == index + 1
                                ? _getUrgencyColor(index + 1)
                                : Colors.transparent,
                            border: Border.all(
                              color: _getUrgencyColor(index + 1),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: urgency == index + 1
                                    ? Colors.white
                                    : _getUrgencyColor(index + 1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '현재 긴급도: ${_getUrgencyLabel(urgency)}',
                style: TextStyle(
                  color: _getUrgencyColor(urgency),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getImportanceLabel(int value) {
    switch (value) {
      case 1:
        return '매우 낮음';
      case 2:
        return '낮음';
      case 3:
        return '보통';
      case 4:
        return '높음';
      case 5:
        return '매우 높음';
      default:
        return '보통';
    }
  }

  Color _getImportanceColor(int value) {
    switch (value) {
      case 1:
        return Colors.blue.shade200;
      case 2:
        return Colors.blue.shade400;
      case 3:
        return Colors.blue.shade600;
      case 4:
        return Colors.blue.shade800;
      case 5:
        return Colors.blue.shade900;
      default:
        return Colors.blue.shade600;
    }
  }

  String _getUrgencyLabel(int value) {
    switch (value) {
      case 1:
        return '여유로움';
      case 2:
        return '천천히';
      case 3:
        return '보통';
      case 4:
        return '빠른 처리';
      case 5:
        return '즉시 처리';
      default:
        return '보통';
    }
  }

  Color _getUrgencyColor(int value) {
    switch (value) {
      case 1:
        return Colors.orange.shade200;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.orange.shade600;
      case 4:
        return Colors.orange.shade800;
      case 5:
        return Colors.red.shade700;
      default:
        return Colors.orange.shade600;
    }
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
            Text('미리 알림',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
            Text('반복',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
          ] else
            if (_repeatOption == '기타') ...[
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

  Widget _buildOptionalTimePicker(
      BuildContext context,
      TimeOfDay? selectedTime,
      String label,
      Function(TimeOfDay?) onTimePicked,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime ?? TimeOfDay.now(),
              );
              if (picked != null) {
                onTimePicked(picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedTime != null
                        ? '${selectedTime.period == DayPeriod.am ? 'AM' : 'PM'} ${selectedTime.hourOfPeriod.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                        : '시간 선택',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedTime != null ? Colors.black : Color(0xFF9AA0A6),
                    ),
                  ),
                  Row(
                    children: [
                      if (selectedTime != null)
                        GestureDetector(
                          onTap: () => onTimePicked(null),
                          child: Icon(Icons.clear, size: 16, color: Colors.grey),
                        ),
                      if (selectedTime != null) SizedBox(width: 4),
                      Icon(Icons.access_time, size: 16, color: Color(0xFF5F6368)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFDADCE0), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202124),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF9575CD),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
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
    final String dialogTitle = widget.todo != null
        ? 'Todo 수정'
        : '새 Todolist 추가';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
      backgroundColor: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Container(
        width: MediaQuery
            .of(context)
            .size
            .width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 다이얼로그 헤더
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: Colors.black12, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF5F6368)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      dialogTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // 폼 영역
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        _titleController,
                        '제목',
                        '제목을 입력하세요 (필수)',
                            (value) {
                          if (value.isEmpty) {
                            setState(() {
                              _titleError = true;
                            });
                          }
                        },
                        prefixIcon: Icon(Icons.title, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 20),

                      _buildDateSelector(),
                      const SizedBox(height: 20),

                      // 시간 설정 (선택사항)
                      _buildTimeSelector(
                          context, _startTime, _endTime, (start, end) {
                        setState(() {
                          _startTime = start;
                          _endTime = end;
                        });
                      }),
                      const SizedBox(height: 20),

                      buildImportanceSelector(
                        importance: _importance,
                        onChanged: (value) {
                          setState(() {
                            _importance = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      buildUrgencySelector(
                        urgency: _urgency,
                        onChanged: (value) {
                          setState(() {
                            _urgency = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // 마감일 선택기 추가
                      _buildDueDateSelector(),
                      const SizedBox(height: 20),

                      // Reminder selector
                      _buildReminderSelector(),
                      const SizedBox(height: 20),

                      // Repeat selector
                      _buildRepeatSelector(),
                      const SizedBox(height: 20),

                      _buildTextField(
                        _locationController,
                        '위치',
                        '위치를 입력하세요.',
                        null,
                        prefixIcon: Icon(Icons.location_on, color: Color(
                            0xFF5F6368)),
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        _memoController,
                        '메모',
                        '메모를 입력하세요.',
                        null,
                        maxLines: 3,
                        prefixIcon: Icon(Icons.note, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 30),

                      // Save and Delete buttons
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 기존 Todo가 있을 때만 삭제 버튼 표시
                            if (widget.isEditing &&
                                widget.onDelete != null) ...[
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _deleteTodo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text('삭제'),
                                ),
                              ),
                            ],
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _validateAndSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF9575CD),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('저장'),
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

// TextField 위젯 (새로 추가)
  Widget _buildTextField(TextEditingController controller,
      String label,
      String hint,
      Function(String)? validator, {
        int maxLines = 1,
        Widget? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5F6368),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
            prefixIcon: prefixIcon,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFDADCE0), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF9575CD), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            errorText: _titleError && controller == _titleController
                ? '제목을 입력해주세요'
                : null,
          ),
          onChanged: (value) {
            if (validator != null) {
              validator(value);
            }
            if (controller == _titleController && _titleError) {
              setState(() {
                _titleError = false;
              });
            }
          },
        ),
      ],
    );
  }
}