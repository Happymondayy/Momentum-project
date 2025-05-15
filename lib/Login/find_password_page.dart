import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FindPasswordPage extends StatefulWidget {
  const FindPasswordPage({Key? key}) : super(key: key);

  @override
  State<FindPasswordPage> createState() => _FindPasswordPageState();
}

class _FindPasswordPageState extends State<FindPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('아이디(이메일)를 입력하세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Auth 비밀번호 재설정 이메일 전송
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('비밀번호 재설정 메일이 $email 으로 전송되었습니다.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showMessage('등록된 이메일이 없습니다.');
      } else if (e.code == 'invalid-email') {
        _showMessage('유효하지 않은 이메일 형식입니다.');
      } else {
        _showMessage('오류가 발생했습니다. 다시 시도해주세요.');
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
        title: const Text('비밀번호 찾기 결과'),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색
      appBar: AppBar(
        backgroundColor: Colors.white, // 배경색 흰색
        elevation: 0, // 그림자 없애기
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
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
                style: TextStyle(
                  fontSize: 25, // 로그인 페이지 제목 크기와 동일하게 맞춤
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // 이메일(아이디) 입력 필드
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '아이디(이메일)를 입력하세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 비밀번호 찾기 버튼
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendPasswordResetEmail,
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
                    '비밀번호 찾기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 로그인 화면으로 돌아가기
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '로그인 화면으로 돌아가기',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                  ),
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
