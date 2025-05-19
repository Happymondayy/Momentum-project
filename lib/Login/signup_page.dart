// signup_page.dart 파일 수정
// 회원가입 시 이메일 중복 확인 및 비밀번호 길이 검증 추가

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

  // 이메일 형식 오류 및 중복 검사 결과 저장 변수
  bool _isEmailValid = true;
  bool _isEmailAvailable = true;
  String _emailErrorMessage = '';

  // 비밀번호 유효성 검사 결과 저장 변수
  bool _isPasswordValid = true;
  String _passwordErrorMessage = '';

  // 닉네임 중복 검사 결과 저장 변수
  bool _isNicknameAvailable = true;
  String _nicknameErrorMessage = '';

  // 로딩 상태 저장 변수
  bool _isCheckingEmail = false;
  bool _isCheckingNickname = false;
  bool _isSigningUp = false;

  // 이메일 형식 검사 함수
  bool _validateEmailFormat(String email) {
    // 간단한 이메일 형식 검사를 위한 정규식
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email);
  }

  // 이메일 중복 확인 함수
  Future<bool> isEmailDuplicate(String email) async {
    try {
      setState(() {
        _isCheckingEmail = true;
      });

      // Firebase Authentication에서 이메일 중복 체크
      final methods = await _auth.fetchSignInMethodsForEmail(email);

      setState(() {
        _isCheckingEmail = false;
      });

      // 로그인 방법이 존재한다면 이미 등록된 이메일
      return methods.isNotEmpty;
    } catch (e) {
      print("이메일 중복 확인 오류: $e");
      setState(() {
        _isCheckingEmail = false;
      });
      return false; // 오류 발생 시 중복 아님으로 처리 (안전하게)
    }
  }

  // 닉네임 중복 체크 함수
  Future<bool> isNicknameDuplicate(String nickname) async {
    if (nickname.isEmpty) return false;

    setState(() {
      _isCheckingNickname = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('user')
          .where('nickname', isEqualTo: nickname)
          .get();

      setState(() {
        _isCheckingNickname = false;
      });

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("닉네임 중복 확인 오류: $e");
      setState(() {
        _isCheckingNickname = false;
      });
      return false; // 오류 발생 시 중복 아님으로 처리
    }
  }

  // 비밀번호 유효성 검사 함수
  bool _validatePassword(String password) {
    // 최소 6자리 검사
    if (password.length < 6) {
      setState(() {
        _isPasswordValid = false;
        _passwordErrorMessage = '비밀번호는 최소 6자리 이상이어야 합니다.';
      });
      return false;
    }

    setState(() {
      _isPasswordValid = true;
      _passwordErrorMessage = '';
    });
    return true;
  }

  // 이메일 필드 변경 시 호출될 함수
  Future<void> _onEmailChanged(String email) async {
    // 이메일 형식 검사
    if (!_validateEmailFormat(email)) {
      setState(() {
        _isEmailValid = false;
        _emailErrorMessage = '유효한 이메일 형식이 아닙니다.';
        _isEmailAvailable = true; // 형식 오류 시 중복 체크는 의미 없음
      });
      return;
    }

    setState(() {
      _isEmailValid = true;
    });

    // 이메일 중복 체크는 형식이 올바를 때만 수행
    if (email.isNotEmpty && _isEmailValid) {
      final isDuplicate = await isEmailDuplicate(email);

      setState(() {
        _isEmailAvailable = !isDuplicate;
        _emailErrorMessage = isDuplicate ? '이미 사용 중인 이메일입니다.' : '';
      });
    }
  }

  // 닉네임 필드 변경 시 호출될 함수
  Future<void> _onNicknameChanged(String nickname) async {
    if (nickname.isEmpty) return;

    final isDuplicate = await isNicknameDuplicate(nickname);

    setState(() {
      _isNicknameAvailable = !isDuplicate;
      _nicknameErrorMessage = isDuplicate ? '이미 사용 중인 닉네임입니다.' : '';
    });
  }

  Future<void> _signUpWithEmailAndPassword() async {
    if (!_validateFormInputs()) return;

    try {
      setState(() {
        _isSigningUp = true;
      });

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

      setState(() {
        _isSigningUp = false;
      });

      navigateToSurvey(userCredential.user!.uid, nicknameController.text.trim());

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSigningUp = false;
      });

      String errorMessage = '회원가입 중 오류가 발생했습니다.';
      if (e.code == 'weak-password') {
        errorMessage = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = '이미 사용 중인 이메일입니다.';
        setState(() {
          _isEmailAvailable = false;
          _emailErrorMessage = errorMessage;
        });
      } else if (e.code == 'invalid-email') {
        errorMessage = '유효하지 않은 이메일 형식입니다.';
        setState(() {
          _isEmailValid = false;
          _emailErrorMessage = errorMessage;
        });
      }
      showErrorSnackBar(errorMessage);
    } catch (e) {
      setState(() {
        _isSigningUp = false;
      });
      showErrorSnackBar('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  // 입력 유효성 검사 통합 함수
  bool _validateFormInputs() {
    bool isValid = true;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    // 이메일 필드 검사
    if (email.isEmpty) {
      setState(() {
        _isEmailValid = false;
        _emailErrorMessage = '이메일을 입력해주세요.';
      });
      isValid = false;
    } else if (!_isEmailValid || !_isEmailAvailable) {
      isValid = false;
    }

    // 비밀번호 필드 검사
    if (password.isEmpty) {
      setState(() {
        _isPasswordValid = false;
        _passwordErrorMessage = '비밀번호를 입력해주세요.';
      });
      isValid = false;
    } else if (!_validatePassword(password)) {
      isValid = false;
    }

    // 닉네임 필드 검사
    if (nickname.isEmpty) {
      setState(() {
        _isNicknameAvailable = false;
        _nicknameErrorMessage = '닉네임을 입력해주세요.';
      });
      isValid = false;
    } else if (!_isNicknameAvailable) {
      isValid = false;
    }

    // 만 14세 이상 체크 검사
    if (!isOver14) {
      showErrorSnackBar('만 14세 이상이어야 가입이 가능합니다.');
      isValid = false;
    }

    return isValid;
  }

  Future<void> signInWithGoogle() async {
    if (!isOver14) {
      showErrorSnackBar('만 14세 이상이어야 가입이 가능합니다.');
      return;
    }

    try {
      setState(() {
        _isSigningUp = true;
      });

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isSigningUp = false;
        });
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

      setState(() {
        _isSigningUp = false;
      });

      navigateToSurvey(userCredential.user!.uid, nickname);

    } catch (e) {
      setState(() {
        _isSigningUp = false;
      });
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
          child: CircularProgressIndicator(color: Colors.deepPurple),
        );
      },
    );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void initState() {
    super.initState();

    // 이메일 필드 리스너 설정
    emailController.addListener(() {
      if (!_isCheckingEmail && emailController.text.isNotEmpty) {
        _onEmailChanged(emailController.text);
      }
    });

    // 비밀번호 필드 리스너 설정
    passwordController.addListener(() {
      if (passwordController.text.isNotEmpty) {
        _validatePassword(passwordController.text);
      }
    });

    // 닉네임 필드 리스너 설정
    nicknameController.addListener(() {
      if (!_isCheckingNickname && nicknameController.text.isNotEmpty) {
        _onNicknameChanged(nicknameController.text);
      }
    });

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
          param1: userId,
          param2: nickname,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            buildInputFieldWithValidation(
              controller: emailController,
              focusNode: emailFocusNode,
              nextFocus: passwordFocusNode,
              hintText: '이메일 등록',
              errorText: _isEmailValid && _isEmailAvailable ? null : _emailErrorMessage,
              suffixIcon: _isCheckingEmail
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              )
                  : _isEmailValid && _isEmailAvailable && emailController.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            const SizedBox(height: 16),

            buildInputFieldWithValidation(
              controller: passwordController,
              focusNode: passwordFocusNode,
              nextFocus: nicknameFocusNode,
              hintText: '비밀번호 등록 (6자리 이상)',
              obscure: true,
              errorText: _isPasswordValid ? null : _passwordErrorMessage,
              suffixIcon: passwordController.text.isNotEmpty && _isPasswordValid
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            const SizedBox(height: 16),

            buildInputFieldWithValidation(
              controller: nicknameController,
              focusNode: nicknameFocusNode,
              nextFocus: null,
              hintText: '닉네임 등록',
              errorText: _isNicknameAvailable ? null : _nicknameErrorMessage,
              suffixIcon: _isCheckingNickname
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              )
                  : _isNicknameAvailable && nicknameController.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
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
                        color: isOver14 ? Colors.deepPurple : Colors.grey,
                        width: 2,
                      ),
                      color: isOver14 ? Colors.deepPurple : Colors.white,
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

            buildMainButton(
              '가입하기',
              onPressed: isOver14 && !_isSigningUp
                  ? _signUpWithEmailAndPassword
                  : null,
              isLoading: _isSigningUp,
            ),

            const SizedBox(height: 16),

            buildMainButton(
              '구글로 가입하기',
              onPressed: isOver14 && !_isSigningUp
                  ? signInWithGoogle
                  : null,
              isGoogle: true,
              isLoading: _isSigningUp,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInputFieldWithValidation({
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode? nextFocus,
    required String hintText,
    bool obscure = false,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: errorText != null ? Colors.red : Colors.grey[300]!,
              width: errorText != null ? 1.5 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              keyboardType: hintText.contains('이메일') ? TextInputType.emailAddress : TextInputType.text,
              textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
              onSubmitted: (_) {
                if (nextFocus != null) {
                  FocusScope.of(context).requestFocus(nextFocus);
                }
              },
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[600]),
                suffixIcon: suffixIcon,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 10.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildMainButton(
      String text, {
        VoidCallback? onPressed,
        bool isGoogle = false,
        bool isLoading = false,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isGoogle ? Colors.white : const Color(0xFFCFCFFF),
          foregroundColor: isGoogle ? Colors.black : Colors.white,
          side: isGoogle ? BorderSide(color: Colors.grey[300]!) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
        ),
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isGoogle ? Colors.deepPurple : Colors.white,
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.g_mobiledata, size: 24),
              ),
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