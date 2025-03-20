import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/survey_screen.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isOver14 = false;//사용자가 동의하면 true로 변경됨

  // 텍스트 필드 컨트롤러 생성
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // 텍스트 필드 포커스 관리를 위한 FocusNode 객체 생성
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 페이지가 로드된 후 약간의 지연 시간을 두고 키보드 표시
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(emailFocusNode);
    });
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위한 컨트롤러 및 FocusNode 해제
    emailController.dispose();
    passwordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  // 설문조사 화면으로 이동하는 함수
  void navigateToSurvey() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SurveyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(//회원가입 페이지의 상단바 역할
        title: const Text('회원가입'), //앱 메인 상단 제목
        backgroundColor: Colors.white,//배경색
        foregroundColor: Colors.black,//글자색
        elevation: 0.5,//그림자 효과
        leading: IconButton(//뒤로 가기 버튼
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),//뒤로 가기 버튼 클릭 시 이전 화면으로 이동
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),//전체 패딩
        child: Column(//여러 위젯을 수직으로 배치
          crossAxisAlignment: CrossAxisAlignment.start,//왼쪽 정렬
          children: [//이메일 입력 필드
            Container(//Container를 사용하여 둥근 테두리가 있는 배경 생성
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),//내부여백 (양옆으로 16px)
                child: TextField(//이메일 입력 필드 추가
                  controller: emailController,
                  focusNode: emailFocusNode, // 포커스 노드 연결
                  keyboardType: TextInputType.emailAddress, // 이메일용 키보드 타입 설정
                  textInputAction: TextInputAction.next, // 키보드의 다음 버튼 활성화
                  onSubmitted: (_) {
                    // 이메일 입력 후 다음 버튼 눌렀을 때 비밀번호 필드로 포커스 이동
                    FocusScope.of(context).requestFocus(passwordFocusNode);
                  },
                  decoration: InputDecoration(
                    hintText: '이메일 등록',//입력칸 힌트 텍스트
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
                  focusNode: passwordFocusNode, // 비밀번호 필드 포커스 노드 연결
                  obscureText: true,//입력 내용 숨기기(비밀번호 입력용)
                  keyboardType: TextInputType.visiblePassword, // 비밀번호용 키보드 타입
                  textInputAction: TextInputAction.done, // 완료 버튼으로 설정
                  onSubmitted: (_) {
                    // 비밀번호 입력 후 완료 버튼 눌렀을 때 키보드 닫기
                    FocusScope.of(context).unfocus();
                    // 만 14세 이상 체크했다면 가입 버튼 자동 클릭 (UX 개선)
                    if (isOver14 && emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
                      navigateToSurvey();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '비밀번호 등록',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),//간격추가
            Row(
              children: [
                GestureDetector(
                  onTap: () {//사용자가 클릭하면 isOVer14 값을 반전시킴(true <-> false)
                    setState(() {
                      isOver14 = !isOver14;//클릭할때마다 true/false 추가
                    });
                  },
                  child: Container(//원형 체크박스 만들기
                    width: 24,//너비 24px
                    height: 24,//높이 24px
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,//원형 테두리
                      border: Border.all(//테두리 추가
                        color: isOver14 ? Colors.red : Colors.grey,//isOVer14 == true -> 빨간색
                        width: 2,
                      ),
                      color: isOver14 ? Colors.red : Colors.white,//isOver14 == false -> 흰색
                    ),
                    child: isOver14
                        ? const Icon(Icons.check, size: 16, color: Colors.white)//isOver14 == true면 체크 아이콘 표시 , isOver == false면 null(아무것도 없음)
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
            // 가입하기 버튼 추가
            SizedBox(
              width: double.infinity, // 버튼의 너비를 화면 전체로 설정
              height: 50, // 버튼 높이
              child: ElevatedButton(
                onPressed: isOver14 ? () {
                  // 가입 로직 구현
                  if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                    // 이메일이나 비밀번호가 비어있으면 경고 메시지 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('이메일과 비밀번호를 모두 입력해주세요.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // 가입 성공 처리 (여기에 실제 가입 API 호출 등의 로직 추가)
                  print('가입하기 버튼이 클릭되었습니다');
                  print('이메일: ${emailController.text}');
                  print('비밀번호: ${passwordController.text}');

                  // 로딩 표시 (선택사항)
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

                  // 가입 처리 지연 시간 시뮬레이션 (실제로는 API 통신 시간)
                  Future.delayed(const Duration(seconds: 1), () {
                    // 로딩 닫기
                    Navigator.pop(context);

                    // 설문조사 화면으로 이동
                    navigateToSurvey();
                  });
                } : null, // isOver14가 false면 버튼 비활성화
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFCFCFFF), // 버튼 배경색
                  foregroundColor: Colors.white, // 버튼 텍스트 색상
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // 버튼 모서리 둥글게
                  ),
                  elevation: 0, // 그림자 없애기
                  disabledBackgroundColor: Colors.grey[300], // 비활성화 상태일 때 배경색
                  disabledForegroundColor: Colors.grey[600], // 비활성화 상태일 때 텍스트 색상
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
          ],
        ),
      ),
    );
  }
}