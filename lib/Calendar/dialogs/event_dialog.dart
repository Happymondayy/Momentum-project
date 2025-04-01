import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Function(String title, DateTime date, TimeOfDay? startTime,
      TimeOfDay? endTime, String memo, bool isRepeating, bool isAllDay) onSave;

  const EventDialog({
    Key? key,
    required this.selectedDay,
    required this.onSave,
  }) : super(key: key);

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventMemoController = TextEditingController();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0);
  bool _isAllDay = false;
  bool _isRepeating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('새 일정 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _eventTitleController,
              decoration: InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text('날짜: ${DateFormat('yyyy-MM-dd').format(widget.selectedDay)}'),
              ],
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('하루 종일'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value!;
                });
              },
            ),
            if (!_isAllDay) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('시작 시간:'),
                  TextButton(
                    child: Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                    onPressed: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('종료 시간:'),
                  TextButton(
                    child: Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                    onPressed: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('반복'),
              value: _isRepeating,
              onChanged: (value) {
                setState(() {
                  _isRepeating = value!;
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _eventMemoController,
              decoration: InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('취소'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('저장'),
          onPressed: () {
            widget.onSave(
              _eventTitleController.text,
              widget.selectedDay,
              _isAllDay ? null : _startTime,
              _isAllDay ? null : _endTime,
              _eventMemoController.text,
              _isRepeating,
              _isAllDay,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}