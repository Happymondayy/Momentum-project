import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onMenuPressed;

  const Header({
    Key? key,
    required this.focusedDay,
    required this.onMenuPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${focusedDay.year}년',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class DateFormat {
}