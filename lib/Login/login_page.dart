import 'package:flutter/material.dart';
import 'signup_page.dart'; // SignupPage를 import
import 'find_ID_page.dart';
import 'find_password_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),//좌우로만 여백을 설정하는 방법
          child: Column(//세로 방향 정렬 (위 -> 아래)
            crossAxisAlignment: CrossAxisAlignment.stretch,//모든 자식 위젯이 가로 방향으로 가능한 최대 크기를 가지도록 설정
            children: [//로고 택스트 맨 상단 "FocusMate"
              const SizedBox(height: 100),
              const Text(
                'FocusMate',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,//중앙 정렬
              ),
              //이메일 입력 필드
              const SizedBox(height: 80),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],//배경색 연한회식색
                  borderRadius: BorderRadius.circular(10),//입력필드 둥글게
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),//여백 추가
                  child: TextField(//입력 필드
                    decoration: InputDecoration(
                      hintText: '이메일을 입력하세요',//입력전 표시되는 문구
                      border: InputBorder.none,//기본 밑줄을 없앰
                      hintStyle: TextStyle(color: Colors.grey[600]),//힌트 텍스트 색상을 회색으로 지정
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),//위쪽 여백
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    obscureText: true,//입력된 텍스트를 가려서 비밀번호처럼 보이도록 설정함.
                    decoration: InputDecoration(
                      hintText: '비밀번호를 입력하세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),//위쪽에 24픽셀의 공간을 추가해서 레이아웃 정리
              ElevatedButton(
                onPressed: () {}, //로그인 기능에 사용
                style: ElevatedButton.styleFrom(//위젯버튼
                  backgroundColor: const Color(0xFFCFCFFF),//버튼의 배경색을 보라색으로 설정
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '로그인',//버튼 안에 "로그인"이라는 글자가 들어있음
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(//버튼을 가로로 배치
                mainAxisAlignment: MainAxisAlignment.center,//중앙
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FindIdPage()),
                      );
                    },
                    child: Text(
                      '아이디 찾기',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FindPasswordPage()),
                      );
                    },
                    child: Text(
                      '비밀번호 찾기',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      // 회원가입 페이지로 네비게이션
                      Navigator.push(//한 화면에서 다른 화면으로 이동(login -> signup)
                        context,//현재 위젯의 위치 정보를 전달
                        MaterialPageRoute(builder: (context) => const SignupPage()),//"회원가입" 버튼을 클릭하면 SignupPage()로 이동
                      );
                    },
                    child: Text(
                      '회원가입',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
