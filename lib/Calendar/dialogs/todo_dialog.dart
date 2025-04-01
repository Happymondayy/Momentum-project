import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TodoDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Function(String title, DateTime date, TimeOfDay time, String memo, bool isRepeating) onSave;

  const TodoDialog({
    Key? key,
    required this.selectedDay,
    required this.onSave,
  }) : super(key: key);

  @override
  _TodoDialogState createState() => _TodoDialogState();
}

class _TodoDialogState extends State<TodoDialog> {
  final TextEditingController _todoTitleController = TextEditingController();
  final TextEditingController _todoMemoController = TextEditingController();
  TimeOfDay _todoTime = TimeOfDay(hour: 9, minute: 0);
  bool _todoIsRepeating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('새 할 일 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _todoTitleController,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('시간:'),
                TextButton(
                  child: Text('${_todoTime.hour.toString().padLeft(2, '0')}:${_todoTime.minute.toString().padLeft(2, '0')}'),
                  onPressed: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: _todoTime,
                    );
                    if (time != null) {
                      setState(() {
                        _todoTime = time;
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text('반복'),
              value: _todoIsRepeating,
              onChanged: (value) {
                setState(() {
                  _todoIsRepeating = value!;
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _todoMemoController,
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
              _todoTitleController.text,
              widget.selectedDay,
              _todoTime,
              _todoMemoController.text,
              _todoIsRepeating,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}