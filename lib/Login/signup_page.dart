import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isOver14 = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController(); // 닉네임 컨트롤러 추가

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode nicknameFocusNode = FocusNode(); // 닉네임 포커스 노드 추가

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _saveUserData() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String nickname = nicknameController.text.trim(); // 닉네임 값 가져오기

    if (email.isEmpty || password.isEmpty || nickname.isEmpty) { // 닉네임 검증 추가
      print("이메일, 비밀번호, 닉네임을 모두 입력하세요.");
      return;
    }

    try {
      // Firestore에 사용자 데이터 저장 (닉네임 포함)
      DocumentReference docRef = await _firestore.collection('user').add({
        'email': email,
        'password': password, // 보안상 실제 앱에서는 비밀번호를 해싱해서 저장해야 함!
        'nickname': nickname, // 닉네임 필드 추가
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("사용자 데이터 저장 완료: 이메일 - $email, 닉네임 - $nickname");

      // 사용자 ID 저장 (회원가입 후 사용자 ID 활용 가능)
      String userId = docRef.id;
      print("생성된 사용자 ID: $userId");

    } catch (e) {
      print('Firestore 오류: $e');
    }
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
    nicknameController.dispose(); // 닉네임 컨트롤러 해제
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    nicknameFocusNode.dispose(); // 닉네임 포커스 노드 해제
    super.dispose();
  }

  void navigateToSurvey(String param1_, String param2_) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SurveyScreen(param1: param1_, param2: param2_),
      ),
    );
  }

  // 구글 로그인 함수 추가
  void signInWithGoogle() {
    // TODO: Google Sign-In 로직 구현
    print('구글로 로그인 시도');

    // 로딩 표시
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

    // 구글 로그인 시뮬레이션 (실제로는 구글 로그인 API 호출 필요)
    Future.delayed(const Duration(seconds: 1), () {
      // 로딩 닫기
      Navigator.pop(context);

      // 설문조사 화면으로 이동
      navigateToSurvey(emailController.text.trim(), passwordController.text.trim());
    });
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
                  textInputAction: TextInputAction.next, // 다음 필드로 이동하도록 변경
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(nicknameFocusNode); // 닉네임 필드로 포커스 이동
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
            // 닉네임 입력 필드 추가
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
                      _saveUserData();
                      navigateToSurvey(emailController.text.trim(), passwordController.text.trim());
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
                      nicknameController.text.isEmpty) { // 닉네임 검증 추가
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('이메일, 비밀번호, 닉네임을 모두 입력해주세요.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  print('가입하기 버튼이 클릭되었습니다');
                  print('이메일: ${emailController.text}');
                  print('비밀번호: ${passwordController.text}');
                  print('닉네임: ${nicknameController.text}');

                  _saveUserData();

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

                  Future.delayed(const Duration(seconds: 1), () {
                    Navigator.pop(context);
                    navigateToSurvey(emailController.text.trim(), passwordController.text.trim());
                  });
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFCFCFFF),
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
            const SizedBox(height: 16), // 구글 로그인 버튼 사이 간격
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
                    Image.asset(
                      'assets/images/google_logo.png', // 구글 로고 이미지 경로 (프로젝트에 추가 필요)
                      height: 24,
                      width: 24,
                    ),
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