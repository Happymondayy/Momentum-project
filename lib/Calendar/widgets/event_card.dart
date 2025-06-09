import 'package:flutter/material.dart';
import '../models/event.dart';
import 'dart:math';

class EventCard extends StatelessWidget {
  final Event event;
  final void Function() onMorePressed;
  final void Function()? onEdit;  // Make optional with nullable type
  final void onDelete;  // Make optional with nullable type

  const EventCard({
    Key? key,
    required this.event,
    required this.onMorePressed,
    this.onEdit,
    this.onDelete,  // Optional parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String timeText = '종일';
    if (event.startTime != null && event.endTime != null) {
      final startFormatted = '${event.startTime!.hour.toString().padLeft(2, '0')}:${event.startTime!.minute.toString().padLeft(2, '0')}';
      final endFormatted = '${event.endTime!.hour.toString().padLeft(2, '0')}:${event.endTime!.minute.toString().padLeft(2, '0')}';
      timeText = '$startFormatted ~ $endFormatted';
    }

    return Card(
      color: Color(0xFFFFFFFF),
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // 네모
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 6, // 작은 동그라미 (기본은 20)
          backgroundColor: getRandomColor(
              event.isLongTerm != '' ? event.isLongTerm : event.id
          ),
        ),
        title: Text(
            event.title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
            ),
        ),
        subtitle: Text(
            timeText,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey
            ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.reminder != null)
              Icon(Icons.notifications, color: Colors.grey[400], size: 16),
            if (event.isRepeating)
              Icon(Icons.repeat, color: Colors.grey[400], size: 16),
          ],
        ),
        onTap: () => onMorePressed(), // ListTile 자체에 onTap 부여
      ),
    );
  }

  Color getRandomColor(String seed) {
    final hash = seed.hashCode;
    final random = Random(hash);
    return Color.fromARGB(
      255,
      100 + random.nextInt(156), // R: 100~255
      100 + random.nextInt(156), // G: 100~255
      100 + random.nextInt(156), // B: 100~255
    );
  }
}