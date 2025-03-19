import 'package:flutter/material.dart';

class FindPasswordPage extends StatelessWidget {
  const FindPasswordPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,//배경색 흰색
        elevation: 0,//그림자 없애기
        leading: IconButton(//앱바의 왼쪽에 아이콘을 배치
          icon: const Icon(Icons.arrow_back, color:  Colors.black),//검정색 뒤로 가기 아이콘(<-)
          onPressed: () => Navigator.pop(context),//뒤로 가기 버튼을 누르면 이전 화면으로 돌아감
        ),
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,//타이틀을 중앙 정렬
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),//화면의 좌우여백을 24px로 설정하여 정렬 맞춤
          child: Column(//요소 세로 정렬
            crossAxisAlignment: CrossAxisAlignment.stretch,//모든 요소들을 가로로 꽉 차게 배치
            children: [
              const SizedBox(height: 60),//여백 추가
              const Text(
                'FocusMate',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              // 아이디 입력 필드
              Container(//아이디 입력 필드를 감싸는 스타일 적용
                decoration: BoxDecoration(//배경색과 둥근 모서리 적용
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(//사용자가 아이디를 입력할 수 있는 입력창
                    decoration: InputDecoration(
                      hintText: '아이디를 입력하세요',//입력 전 안내 문구
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 전화번호 입력 필드
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    keyboardType: TextInputType.phone,//전화번호 입력 시 숫자 키보드 표시
                    decoration: InputDecoration(
                      hintText: '전화번호를 입력하세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 비밀번호 찾기 버튼
              ElevatedButton(
                onPressed: () {//버튼 클릭시 비밃번호 찾기 기능 실행하도록 구현
                  // 비밀번호 찾기 기능 구현
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCFCFFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '비밀번호 찾기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 로그인 화면으로 돌아가기
              TextButton(
                onPressed: () {
                  Navigator.pop(context);//로그인 화면으로 돌아감
                },
                child: Text(
                  '로그인 화면으로 돌아가기',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
