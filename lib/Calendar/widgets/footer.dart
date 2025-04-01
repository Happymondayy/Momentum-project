import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  final Function() onCalendarPressed;
  final Function() onListPressed;
  final Function() onEditPressed;
  final Function() onChatPressed;

  const Footer({
    Key? key,
    required this.onCalendarPressed,
    required this.onListPressed,
    required this.onEditPressed,
    required this.onChatPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: Colors.blue),
            onPressed: onCalendarPressed,
          ),
          IconButton(
            icon: Icon(Icons.list_alt, color: Colors.grey),
            onPressed: onListPressed,
          ),
          IconButton(
            icon: Icon(Icons.edit_note, color: Colors.grey),
            onPressed: onEditPressed,
          ),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.grey),
            onPressed: onChatPressed,
          ),
        ],
      ),
    );
  }
}