import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Function(bool?) onStatusChanged;
  final void Function() onMorePressed;
  final void Function()? onEdit;  // Make optional with nullable type
  final void Function()? onDelete;  // Make optional with nullable type

  const TodoCard({
    Key? key,
    required this.todo,
    required this.onStatusChanged,
    required this.onMorePressed,
    this.onEdit,
    this.onDelete,  // Optional parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 마감일까지 남은 일수 계산
    int? daysUntilDue;
    Color? dueDateColor;
    String? dueDateText;

    if (todo.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);

      daysUntilDue = dueDate.difference(today).inDays;

      if (daysUntilDue < 0) {
        dueDateColor = Colors.red;
        dueDateText = '${(-daysUntilDue)}일 지남';
      } else if (daysUntilDue == 0) {
        dueDateColor = Colors.orange;
        dueDateText = '오늘까지';
      } else if (daysUntilDue == 1) {
        dueDateColor = Colors.orange;
        dueDateText = '내일까지';
      } else if (daysUntilDue <= 3) {
        dueDateColor = Colors.amber;
        dueDateText = '${daysUntilDue}일 남음';
      } else {
        dueDateColor = Colors.grey;
        dueDateText = '${daysUntilDue}일 남음';
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: InkWell(
        onTap: onMorePressed,  // 카드 전체에 onTap 적용
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: todo.isCompleted,
                onChanged: (value) => onStatusChanged(value!),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (!todo.isAllDay && todo.startTime != null)
                          Text(
                            todo.getFormattedStartTime(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: todo.isCompleted ? Colors.grey : Colors.black54,
                            ),
                          ),
                        if (todo.location.isNotEmpty)
                          Row(
                            children: [
                              SizedBox(width: 8),
                              Icon(Icons.location_on, size: 12, color: Colors.grey),
                              SizedBox(width: 2),
                              Text(
                                todo.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: todo.isCompleted ? Colors.grey : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        // 마감일 표시 추가
                        if (dueDateText != null)
                          Row(
                            children: [
                              SizedBox(width: 8),
                              Icon(Icons.schedule, size: 12, color: dueDateColor),
                              SizedBox(width: 2),
                              Text(
                                dueDateText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: todo.isCompleted ? Colors.grey : dueDateColor,
                                  fontWeight: daysUntilDue != null && daysUntilDue <= 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 오른쪽 아이콘 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPriorityChip(context, '⭐', todo.importance, Colors.blue),
                  SizedBox(width: 6),
                  _buildPriorityChip(context, '⏰', todo.urgency, Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, String symbol, int value, Color baseColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1 + (value / 10)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$symbol$value',
        style: TextStyle(
          fontSize: 11,
          color: baseColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}