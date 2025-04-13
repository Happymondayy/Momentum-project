import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Function(bool?) onStatusChanged;
  final VoidCallback onMorePressed;

  const TodoCard({
    Key? key,
    required this.todo,
    required this.onStatusChanged,
    required this.onMorePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (value) {
            onStatusChanged(value!);
          },
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: todo.time != null
            ? Text('${todo.time!.hour.toString().padLeft(2, '0')}:${todo.time!.minute.toString().padLeft(2, '0')}')
            : null,
        trailing: IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: onMorePressed,
        ),
      ),
    );
  }
}