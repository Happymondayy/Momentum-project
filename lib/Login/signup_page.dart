import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 인증 추가
import 'package:google_sign_in/google_sign_in.dart'; // Google 로그인 추가

class SignupPage extends StatefulWidget {
  SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isOver14 = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode nicknameFocusNode = FocusNode();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase 인증 인스턴스 추가
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Google 로그인 인스턴스 추가

  // Firebase 이메일/비밀번호로 회원가입
  Future<void> _signUpWithEmailAndPassword() async {
    try {
      // 로딩 표시
      showLoadingDialog();

      // Firebase Auth로 사용자 등록
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Firestore에 사용자 추가 정보 저장
      await _saveUserDataToFirestore(
          userId: userCredential.user!.uid,
          email: emailController.text.trim(),
          nickname: nicknameController.text.trim(),
          authProvider: 'email'
      );

      // 로딩 닫기
      Navigator.pop(context);

      // 설문조사 화면으로 이동
      navigateToSurvey(userCredential.user!.uid, nicknameController.text.trim());

    } on FirebaseAuthException catch (e) {
      // 로딩 닫기
      Navigator.pop(context);

      String errorMessage = '회원가입 중 오류가 발생했습니다.';
      if (e.code == 'weak-password') {
        errorMessage = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        errorMessage = '유효하지 않은 이메일 형식입니다.';
      }

      showErrorSnackBar(errorMessage);
    } catch (e) {
      // 로딩 닫기
      Navigator.pop(context);
      showErrorSnackBar('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  // 구글 로그인 구현
  Future<void> signInWithGoogle() async {
    try {
      // 로딩 표시
      showLoadingDialog();

      // Google Sign-In 플로우 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // 사용자가 로그인 취소한 경우
      if (googleUser == null) {
        Navigator.pop(context); // 로딩 닫기
        return;
      }

      // 인증 정보 얻기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase에 Google 계정으로 인증
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Auth로 로그인
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // 새 사용자인지 확인
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      // 사용자 정보 저장 (새 사용자인 경우)
      if (isNewUser) {
        // 닉네임은 Google 계정의 displayName을 기본값으로 사용
        String nickname = userCredential.user?.displayName ?? '사용자';

        await _saveUserDataToFirestore(
            userId: userCredential.user!.uid,
            email: userCredential.user!.email!,
            nickname: nickname,
            authProvider: 'google'
        );
      }

      // 사용자 정보 가져오기
      DocumentSnapshot userDoc = await _firestore
          .collection('user')
          .doc(userCredential.user!.uid)
          .get();

      String nickname = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '사용자'
          : userCredential.user?.displayName ?? '사용자';

      // 로딩 닫기
      Navigator.pop(context);

      // 설문조사 화면으로 이동
      navigateToSurvey(userCredential.user!.uid, nickname);

    } catch (e) {
      // 로딩 닫기
      if (context.mounted) Navigator.pop(context);
      showErrorSnackBar('구글 로그인 중 오류가 발생했습니다: $e');
    }
  }

  // Firestore에 사용자 데이터 저장
  Future<void> _saveUserDataToFirestore({
    required String userId,
    required String email,
    required String nickname,
    required String authProvider,
  }) async {
    await _firestore.collection('user').doc(userId).set({
      'email': email,
      'nickname': nickname,
      'authProvider': authProvider, // 인증 제공자 저장 (email 또는 google)
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // 로딩 다이얼로그 표시
  void showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.red,
          ),
        );
      },
    );
  }

  // 에러 메시지 표시
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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
    nicknameController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    nicknameFocusNode.dispose();
    super.dispose();
  }

  void navigateToSurvey(String userId, String nickname) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SurveyScreen(param1: userId, param2: nickname),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
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
                    hintText: '이메일 등록',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(nicknameFocusNode);
                  },
                  decoration: InputDecoration(
                    hintText: '비밀번호 등록',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: nicknameController,
                  focusNode: nicknameFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                    if (isOver14 && emailController.text.isNotEmpty &&
                        passwordController.text.isNotEmpty &&
                        nicknameController.text.isNotEmpty) {
                      _signUpWithEmailAndPassword();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '닉네임 등록',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isOver14 = !isOver14;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOver14 ? Colors.red : Colors.grey,
                        width: 2,
                      ),
                      color: isOver14 ? Colors.red : Colors.white,
                    ),
                    child: isOver14
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '필수',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('만 14세 이상입니다.'),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isOver14 ? () {
                  if (emailController.text.isEmpty ||
                      passwordController.text.isEmpty ||
                      nicknameController.text.isEmpty) {
                    showErrorSnackBar('이메일, 비밀번호, 닉네임을 모두 입력해주세요.');
                    return;
                  }
                  _signUpWithEmailAndPassword();
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCFCFFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
                child: const Text(
                  '가입하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isOver14 ? signInWithGoogle : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[100],
                  disabledForegroundColor: Colors.grey[500],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 10),
                    const Text(
                      '구글로 가입하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}