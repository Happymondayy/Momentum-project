// custom_calendar_picker.dart
import 'package:flutter/material.dart';

class CustomCalendarPicker extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Function(DateTime) onDateSelected;
  final String title;
  final Color primaryColor;

  const CustomCalendarPicker({
    Key? key,
    this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onDateSelected,
    this.title = '날짜 선택',
    this.primaryColor = const Color(0xFF5E4DAE),
  }) : super(key: key);

  @override
  State<CustomCalendarPicker> createState() => _CustomCalendarPickerState();
}

class _CustomCalendarPickerState extends State<CustomCalendarPicker> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildCalendar(),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _canGoPreviousMonth() ? _previousMonth : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: _canGoPreviousMonth() ? widget.primaryColor : Colors.grey,
                ),
              ),
              Text(
                '${_currentMonth.year}년 ${_currentMonth.month}월',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _canGoNextMonth() ? _nextMonth : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: _canGoNextMonth() ? widget.primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWeekHeader(),
          SizedBox(height: 8),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: weekdays.map((day) => Expanded(
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startDate = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));

    List<Widget> dayWidgets = [];

    for (int i = 0; i < 42; i++) {
      final date = startDate.add(Duration(days: i));
      dayWidgets.add(_buildDayWidget(date));
    }

    return Column(
      children: [
        for (int week = 0; week < 6; week++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: dayWidgets.sublist(week * 7, (week + 1) * 7).map((widget) =>
                Expanded(child: widget)
            ).toList(),
          ),
      ],
    );
  }

  Widget _buildDayWidget(DateTime date) {
    final isCurrentMonth = date.month == _currentMonth.month;
    final isSelected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;
    final isToday = _isToday(date);
    final isEnabled = _isDateEnabled(date);

    return GestureDetector(
      onTap: isEnabled ? () => _selectDate(date) : null,
      child: Container(
        height: 40,
        margin: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.primaryColor
              : isToday
              ? widget.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : isToday
              ? Border.all(color: widget.primaryColor, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: !isEnabled
                ? Colors.grey[400]
                : isSelected
                ? Colors.white
                : !isCurrentMonth
                ? Colors.grey[400]
                : isToday
                ? widget.primaryColor
                : Colors.black,
            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedDate != null
                ? () {
              widget.onDateSelected(_selectedDate!);
              Navigator.of(context).pop();
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('선택'),
          ),
        ],
      ),
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  bool _canGoPreviousMonth() {
    if (widget.minDate == null) return true;
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    return previousMonth.isAfter(DateTime(widget.minDate!.year, widget.minDate!.month - 1));
  }

  bool _canGoNextMonth() {
    if (widget.maxDate == null) return true;
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    return nextMonth.isBefore(DateTime(widget.maxDate!.year, widget.maxDate!.month + 1));
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  bool _isDateEnabled(DateTime date) {
    if (widget.minDate != null && date.isBefore(widget.minDate!)) {
      return false;
    }
    if (widget.maxDate != null && date.isAfter(widget.maxDate!)) {
      return false;
    }
    return true;
  }
}

// 사용하기 쉬운 헬퍼 함수
class CalendarPickerUtils {
  static Future<DateTime?> showCalendarPicker({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    String title = '날짜 선택',
    Color primaryColor = Colors.blue,
  }) {
    DateTime? selectedDate;

    return showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: CustomCalendarPicker(
            initialDate: initialDate,
            minDate: minDate,
            maxDate: maxDate,
            title: title,
            primaryColor: primaryColor,
            onDateSelected: (date) {
              selectedDate = date;
            },
          ),
        );
      },
    ).then((_) => selectedDate);
  }
}

// 날짜 박스 위젯 (기존 코드에서 사용)
class DateSelectorBox extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final Color primaryColor;

  const DateSelectorBox({
    Key? key,
    required this.label,
    required this.date,
    required this.onTap,
    this.primaryColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨을 박스 위에 표시
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        // 날짜 박스
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                )
              ],
            ),
            child: Row(
              children: [
                Text(
                  _getFormattedDate(date),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getFormattedDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}