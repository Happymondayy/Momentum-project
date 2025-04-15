import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner_Todo/task_events.dart';
import 'package:momentum_planner/Planner_Todo/task_todo.dart';

class EventFormDialog extends StatefulWidget {
  final List<Task> tasks;
  final Function(PlannerEvent) onSave;
  final DateTime selectedDate;

  const EventFormDialog({
    Key? key,
    required this.tasks,
    required this.onSave,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _EventFormDialogState createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  late Task selectedTask;
  String? location;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? note;
  Color eventColor = Colors.blue.shade100;

  @override
  void initState() {
    super.initState();
    selectedTask = widget.tasks.first;
    startTime = selectedTask.startTime;
    endTime = selectedTask.endTime;
    note = selectedTask.note;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이벤트 생성하기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작업 선택
            DropdownButtonFormField<Task>(
              value: selectedTask,
              decoration: const InputDecoration(
                labelText: '작업 선택',
              ),
              items: widget.tasks.map((Task task) {
                return DropdownMenuItem<Task>(
                  value: task,
                  child: Text(task.title),
                );
              }).toList(),
              onChanged: (Task? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedTask = newValue;
                    startTime = newValue.startTime;
                    endTime = newValue.endTime;
                    note = newValue.note;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 시작 시간
            ListTile(
              title: const Text('시작 시간'),
              subtitle: Text(startTime != null
                  ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
                  : '선택하세요'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: startTime ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    startTime = picked;
                  });
                }
              },
            ),

            // 종료 시간
            ListTile(
              title: const Text('종료 시간'),
              subtitle: Text(endTime != null
                  ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                  : '선택하세요'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: endTime ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    endTime = picked;
                  });
                }
              },
            ),

            // 위치
            TextField(
              decoration: const InputDecoration(
                labelText: '위치',
                hintText: '선택사항',
              ),
              onChanged: (value) {
                location = value;
              },
            ),

            // 메모
            TextField(
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '선택사항',
              ),
              maxLines: 3,
              controller: TextEditingController(text: note),
              onChanged: (value) {
                note = value;
              },
            ),

            const SizedBox(height: 16),

            // 색상 선택
            const Text('이벤트 색상'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _colorOption(Colors.blue.shade100),
                _colorOption(Colors.green.shade100),
                _colorOption(Colors.orange.shade100),
                _colorOption(Colors.purple.shade100),
                _colorOption(Colors.red.shade100),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (startTime != null && endTime != null) {
              final event = PlannerEvent(
                id: selectedTask.id,
                title: selectedTask.title,
                date: widget.selectedDate,
                startTime: startTime!,
                endTime: endTime!,
                note: note,
                location: location,
                color: eventColor,
              );

              widget.onSave(event);
              Navigator.of(context).pop();
            } else {
              // 시간을 선택하지 않은 경우 경고 메시지
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('시작 시간과 종료 시간을 선택해주세요')),
              );
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _colorOption(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          eventColor = color;
        });
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: eventColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}