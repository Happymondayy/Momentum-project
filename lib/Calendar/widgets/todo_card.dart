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