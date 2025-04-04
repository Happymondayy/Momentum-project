import 'package:flutter/material.dart';
import '../models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onMorePressed;

  const EventCard({
    Key? key,
    required this.event,
    required this.onMorePressed,
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.event_note, color: Colors.grey),
        ),
        title: Text(event.title),
        subtitle: Text(timeText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications, color: Colors.amber),
            if (event.isRepeating)
              Icon(Icons.repeat, color: Colors.blue),
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: onMorePressed,
            ),
          ],
        ),
      ),
    );
  }
}