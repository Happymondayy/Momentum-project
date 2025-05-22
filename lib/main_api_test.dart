import 'package:flutter/material.dart';
import 'screens/api_test_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Test',
      home: ApiTestScreen(),
    );
  }
}
