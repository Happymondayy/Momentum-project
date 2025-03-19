import 'package:flutter/material.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool isOver14 = false;//사용자가 동의하면 true로 변경됨

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(//회원가입 페이지의 상단바 역할
        title: const Text('가입하기'), //앱 메인 상단 제목
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
                  obscureText: true,//입력 내용 숨기기(비밀번호 입력용)
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
                        color: isOver14 ? Colors. red : Colors.grey,//isOVer14 == true -> 빨간색
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
          ],
        ),
      ),
    );
  }
}
