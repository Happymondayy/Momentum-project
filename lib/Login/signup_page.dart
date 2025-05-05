import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signUpWithEmailAndPassword() async {
    try {
      showLoadingDialog();

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _saveUserDataToFirestore(
        userId: userCredential.user!.uid,
        email: emailController.text.trim(),
        nickname: nicknameController.text.trim(),
        authProvider: 'email',
      );

      Navigator.pop(context);

      navigateToSurvey(userCredential.user!.uid, nicknameController.text.trim());

    } on FirebaseAuthException catch (e) {
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
      Navigator.pop(context);
      showErrorSnackBar('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      showLoadingDialog();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        Navigator.pop(context);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        String nickname = userCredential.user?.displayName ?? '사용자';
        await _saveUserDataToFirestore(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email!,
          nickname: nickname,
          authProvider: 'google',
        );
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('user')
          .doc(userCredential.user!.uid)
          .get();

      String nickname = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '사용자'
          : userCredential.user?.displayName ?? '사용자';

      Navigator.pop(context);
      navigateToSurvey(userCredential.user!.uid, nickname);

    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      showErrorSnackBar('구글 로그인 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _saveUserDataToFirestore({
    required String userId,
    required String email,
    required String nickname,
    required String authProvider,
  }) async {
    await _firestore.collection('user').doc(userId).set({
      'email': email,
      'nickname': nickname,
      'authProvider': authProvider,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.red),
        );
      },
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        builder: (context) => SurveyScreen(
          param1: userId,     // 예: 이메일일 경우 변수명 수정 필요
          param2: nickname,   // 닉네임
          userId: userId,     // 여기! 올바른 userId 전달
        ),
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
            buildInputField(emailController, emailFocusNode, passwordFocusNode, '이메일 등록'),
            const SizedBox(height: 16),
            buildInputField(passwordController, passwordFocusNode, nicknameFocusNode, '비밀번호 등록', obscure: true),
            const SizedBox(height: 16),
            buildInputField(nicknameController, nicknameFocusNode, null, '닉네임 등록', onSubmit: () {
              if (isOver14 && emailController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty &&
                  nicknameController.text.isNotEmpty) {
                _signUpWithEmailAndPassword();
              }
            }),
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
            buildMainButton('가입하기', onPressed: isOver14 ? () {
              if (emailController.text.isEmpty ||
                  passwordController.text.isEmpty ||
                  nicknameController.text.isEmpty) {
                showErrorSnackBar('이메일, 비밀번호, 닉네임을 모두 입력해주세요.');
                return;
              }
              _signUpWithEmailAndPassword();
            } : null),
            const SizedBox(height: 16),
            buildMainButton('구글로 가입하기',
                onPressed: isOver14 ? signInWithGoogle : null,
                isGoogle: true),
          ],
        ),
      ),
    );
  }

  Widget buildInputField(TextEditingController controller, FocusNode focusNode, FocusNode? nextFocus, String hintText,
      {bool obscure = false, VoidCallback? onSubmit}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: TextInputType.emailAddress,
          textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
              if (onSubmit != null) onSubmit();
            }
          },
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget buildMainButton(String text, {VoidCallback? onPressed, bool isGoogle = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isGoogle ? Colors.white : const Color(0xFFCFCFFF),
          foregroundColor: isGoogle ? Colors.black : Colors.white,
          side: isGoogle ? BorderSide(color: Colors.grey[300]!) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle) const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
