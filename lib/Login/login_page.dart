import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:momentum_planner/Login/find_password_page.dart';
import 'package:momentum_planner/Login/signup_page.dart';
import 'package:momentum_planner/Calendar/screens/calendar_screen.dart';

import 'find_ID_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();

        String userId;
        if (userDoc.docs.isNotEmpty) {
          userId = userDoc.docs.first.id;
        } else {
          final newDoc = await _firestore.collection('users').add({
            'email': user.email,
            'name': user.displayName ?? '',
            'googleLogin': false,
          });
          userId = newDoc.id;
        }

        print('로그인 성공! userId = $userId');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarScreen(userId: userId),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '로그인 실패';

      switch (e.code) {
        case 'invalid-email':
          message = '유효하지 않은 이메일입니다.';
          break;
        case 'user-not-found':
          message = '존재하지 않는 사용자입니다.';
          break;
        case 'wrong-password':
          message = '비밀번호가 틀렸습니다.';
          break;
        case 'network-request-failed':
          message = '네트워크 연결에 실패했습니다. 인터넷 상태를 확인하세요.';
          break;
        default:
          message = e.message ?? '알 수 없는 오류가 발생했습니다.';
      }

      _showError(message);
    } catch (e) {
      _showError('알 수 없는 오류가 발생했습니다.');
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();

        String userId;
        if (userDoc.docs.isNotEmpty) {
          userId = userDoc.docs.first.id;
        } else {
          final docRef = await _firestore.collection('users').add({
            'email': user.email,
            'name': user.displayName ?? '',
            'googleLogin': true,
          });
          userId = docRef.id;
        }

        print('Google 로그인 성공! userId = $userId');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarScreen(userId: userId),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Google 로그인 실패';

      if (e.code == 'network-request-failed') {
        message = '네트워크 오류로 Google 로그인에 실패했습니다.';
      } else {
        message = e.message ?? 'Google 로그인 중 알 수 없는 오류가 발생했습니다.';
      }

      _showError(message);
    } catch (e) {
      _showError('Google 로그인 중 알 수 없는 오류가 발생했습니다.');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'FocusMate',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(_emailController, '이메일을 입력하세요'),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, '비밀번호를 입력하세요', isPassword: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9D7F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: GestureDetector(
                  onTap: _loginWithGoogle,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Google로 로그인',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLink('아이디 찾기', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FindIdPage()),
                    );
                  }),
                  _buildLink('비밀번호 찾기', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FindPasswordPage()),
                    );
                  }),
                  _buildLink('회원가입', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupPage()),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
        ),
      ),
    );
  }
}
