import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Text('📅', style: TextStyle(fontSize: 24, color: Colors.grey)),
          Text('📋', style: TextStyle(fontSize: 24, color: Colors.grey)),
          Text('✏️', style: TextStyle(fontSize: 24, color: Colors.grey)),
          Text('💬', style: TextStyle(fontSize: 24, color: Colors.grey)),
        ],
      ),
    );
  }
}