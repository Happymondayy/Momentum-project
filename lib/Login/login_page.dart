import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:momentum_planner/Login/find_password_page.dart';
import 'package:momentum_planner/Login/signup_page.dart';
import 'package:momentum_planner/Calendar/screens/calendar_screen.dart';

import '../Calendar/screens/calendar_screen.dart'; // ✅ 변경된 부분

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

        // ✅ 변경된 부분: BottomNav -> CalendarScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarScreen(userId: userId),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError('로그인 실패: ${e.message}');
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

        // ✅ 변경된 부분: BottomNav -> CalendarScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarScreen(userId: userId),
          ),
        );
      }
    } catch (e) {
      _showError('Google 로그인 중 오류가 발생했습니다.');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('오류'),
        content: Text(message),
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
              const SizedBox(height: 60),
              Text(
                'FocusMate',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 60),
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
                    backgroundColor: Color(0xFFD9D7F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '로그인',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _loginWithGoogle,
                child: Text(
                  'Google로 로그인',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLink('아이디 찾기', () {}),
                  _buildLink('비밀번호 찾기', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => FindPasswordPage()),
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
        color: Color(0xFFEDEDED),
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
        style: TextStyle(
          color: Colors.black54,
          fontSize: 13,
        ),
      ),
    );
  }
}
