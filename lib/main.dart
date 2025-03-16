import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore 데이터 추가 및 가져오기
  Future<void> _testFirestore() async {
    try {
      // 데이터 추가
      await _firestore.collection('testCollection').add({
        'message': 'Hello, Firebase!',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 데이터 가져오기
      var snapshot = await _firestore.collection('testCollection').get();
      snapshot.docs.forEach((doc) {
        print('문서 ID: ${doc.id}, 데이터: ${doc.data()}');
      });
    } catch (e) {
      print('Firestore 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase 연동 테스트',
      home: Scaffold(
        appBar: AppBar(title: Text('Firestore 데이터 테스트')),
        body: Center(
          child: ElevatedButton(
            onPressed: _testFirestore,  // 버튼 클릭 시 Firestore 테스트 실행
            child: Text('Firestore 테스트'),
          ),
        ),
      ),
    );
  }
}
