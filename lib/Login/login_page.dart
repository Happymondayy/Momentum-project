import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:momentum_planner/Login/signup_page.dart'; // 회원가입 페이지 import

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(emailFocusNode);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  void navigateToHome(String email, String userId) {
    // 사용자 정보를 가지고 홈 화면으로 이동
    // 홈 화면이 있다면 그쪽으로 이동하거나, 설문조사 화면으로 이동할 수 있습니다
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SurveyScreen(param1: email, param2: userId),
      ),
    );
  }

  void navigateToSignUp() {
    // 회원가입 페이지로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SignupPage(),
      ),
    );
  }

  // 이메일/비밀번호 로그인
  Future<void> signInWithEmailPassword() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일과 비밀번호를 모두 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFCFCFFF),
            ),
          );
        },
      );

      // Firebase 이메일/비밀번호 로그인
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      // 로딩 닫기
      Navigator.pop(context);

      if (user != null) {
        // 로그인 성공 시 홈 화면으로 이동
        navigateToHome(user.email ?? '', user.uid);
      }
    } catch (e) {
      // 로딩 닫기
      if (context.mounted) Navigator.pop(context);

      // 에러 메시지 처리
      String errorMessage = '로그인 실패';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = '등록되지 않은 이메일입니다.';
            break;
          case 'wrong-password':
            errorMessage = '비밀번호가 일치하지 않습니다.';
            break;
          case 'invalid-email':
            errorMessage = '유효하지 않은 이메일 형식입니다.';
            break;
          case 'user-disabled':
            errorMessage = '비활성화된 계정입니다.';
            break;
          default:
            errorMessage = '로그인 중 오류가 발생했습니다: ${e.code}';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      print('로그인 오류: $e');
    }
  }

  // 구글 로그인
  Future<void> signInWithGoogle() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFCFCFFF),
            ),
          );
        },
      );

      // Google Sign-In 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // 사용자가 로그인 취소한 경우
      if (googleUser == null) {
        Navigator.pop(context); // 로딩 닫기
        return;
      }

      // Google Sign-In 인증 정보 획득
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase에 Google 인증 정보로 로그인
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Authentication에 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // 로딩 닫기
      Navigator.pop(context);

      if (user != null) {
        // 사용자 정보 확인
        final docSnapshot = await _firestore.collection('user').doc(user.uid).get();

        // 새 사용자인 경우 기본 정보 저장
        if (!docSnapshot.exists) {
          await _firestore.collection('user').doc(user.uid).set({
            'email': user.email,
            'nickname': user.displayName ?? '사용자${user.uid.substring(0, 5)}',
            'authProvider': 'google',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // 홈 화면으로 이동
        navigateToHome(user.email ?? '', user.uid);
      }
    } catch (e) {
      // 로딩 닫기
      if (context.mounted) Navigator.pop(context);

      // 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구글 로그인 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('구글 로그인 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이메일 입력 필드
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: emailController,
                  focusNode: emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(passwordFocusNode);
                  },
                  decoration: InputDecoration(
                    hintText: '이메일',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 비밀번호 입력 필드
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: true,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                    if (emailController.text.isNotEmpty &&
                        passwordController.text.isNotEmpty) {
                      signInWithEmailPassword();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 자동 로그인 체크박스
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      rememberMe = !rememberMe;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: rememberMe ? Color(0xFFCFCFFF) : Colors.grey,
                        width: 2,
                      ),
                      color: rememberMe ? Color(0xFFCFCFFF) : Colors.white,
                    ),
                    child: rememberMe
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('자동 로그인'),

                const Spacer(),

                // 비밀번호 찾기 텍스트 버튼
                GestureDetector(
                  onTap: () {
                    // 비밀번호 찾기 페이지로 이동하는 로직
                    // TODO: 비밀번호 찾기 페이지 구현 후 연결
                  },
                  child: const Text(
                    '비밀번호 찾기',
                    style: TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: signInWithEmailPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFCFCFFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 구글 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 구글 로고가 없는 경우를 대비해 아이콘으로 대체
                    Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Text(
                      '구글 로그인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 회원가입 안내
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('계정이 없으신가요?'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: navigateToSignUp,
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      color: Color(0xFFCFCFFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}