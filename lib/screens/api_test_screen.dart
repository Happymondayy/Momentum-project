import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ApiTestScreen extends StatefulWidget {
  @override
  _ApiTestScreenState createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _result = '';
  bool _isLoading = false;

  // 간단한 API 테스트
  Future<void> _testApi() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // 간단한 일정 생성 테스트
      final result = await ApiService.createSchedule(
        tasks: [
          {
            'title': '테스트 작업',
            'importance': 2,
            'urgency': 2,
          }
        ],
        calendar: [
          {
            'title': '테스트 일정',
            'date': '2025-05-22',
            'startTime': '10:00',
            'endTime': '11:00',
          }
        ],
      );

      setState(() {
        _isLoading = false;
        if (result['success']) {
          _result = 'API 연결 성공!\n데이터: ${result['data']}';
        } else {
          _result = 'API 연결 실패: ${result['error']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = '오류 발생: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API 연결 테스트'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _testApi,
                child: Text('API 테스트하기'),
              ),

            SizedBox(height: 20),

            if (_result.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}