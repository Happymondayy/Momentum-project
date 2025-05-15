import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FindIdPage extends StatefulWidget {
  const FindIdPage({Key? key}) : super(key: key);

  @override
  State<FindIdPage> createState() => _FindIdPageState();
}

class _FindIdPageState extends State<FindIdPage> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _findEmailByNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showMessage('닉네임을 입력하세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final email = querySnapshot.docs.first['email'];
        _showMessage('가입하신 이메일은 $email 입니다.');
      } else {
        _showMessage('해당 닉네임으로 등록된 계정이 없습니다.');
      }
    } catch (e) {
      _showMessage('오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('아이디 찾기 결과'),
        content: Text(
          message,
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '아이디 찾기',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Text(
                'FocusMate',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: '닉네임을 입력하세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _findEmailByNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCFCFFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    '아이디 찾기',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '로그인 화면으로 돌아가기',
                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
