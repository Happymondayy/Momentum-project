import 'package:flutter/material.dart';

void main() {
  runApp(const SurveyApp());
}

class SurveyApp extends StatelessWidget{
  const SurveyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, //앱 기본 색상 팔레트 정의
        scaffoldBackgroundColor: Colors.white, //화면 배경색
    ),
    home: const SurveyScreen(),
    );
  }
}

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({Key? key}) : super(key: key);

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> with SingleTickerProviderStateMixin {
  int currentQuestionIndex = 0;
  late AnimationController _animationController;//애니메이션 상태(실행, 속도 등) 조절
  late Animation<Offset> _currentQuestionAnimation; // 현재 위치(좌표)
  late Animation<Offset> _nextQuestionAnimation; // 다음 위치(좌표)

  final List<Map<String, dynamic>> questions = [
    {
      'prompt': '활동하기 가장 편한 시간대는 언제인가요?',
      'value': '아침',
      'options': ['아침', '점심', '저녁', '밤'],
      'state': false,
    },
    {
      'prompt': '평소 수면 시간이 어떻게 되나요?',
      'value': 'PM 11:00 ~ AM 07:00',
      'options': ['PM 11:00 ~ AM 07:00', 'AM 07:00 ~ PM 03:00', 'PM 03:00 ~ PM 11:00'],
      'state': false,
    },
    {
      'prompt': '작업 중 얼마나 자유 휴식을 취하나요?',
      'value': '30분마다',
      'options': ['30분마다', '1시간마다', '2시간마다', '3시간이상'],
      'state': false,
    },
  ];

  /*
  void goToNextQuestion(){
    setState(() {
      if(currentQuestionIndex < questions.length - 1){
        currentQuestionIndex++;
      }
    });
  }

  void activateQuestion(int index){
    setState(() {
      currentQuestionIndex = index;
    });
  } */

  @override
  void initState() {
    super.initState();

    // 위젯 초기 상태 설정
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),//애니메이션 지속 시간
      vsync: this, //화면 프레임과 동기화하기 위한 신호(현재 상태 클래스를 참조)
    );

    //현재 질문 이동 애니메이션
    _currentQuestionAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0), // 시작 위치
      end: const Offset(0.0, -1.0), // 나중 위치
    ).animate(CurvedAnimation( //속도 변화 곡선 정의
      parent: _animationController, //애니메이션 진행 상태(0.0 -> 1.0) 관리
      curve: Curves.easeInOut, // 애니메이션 시작과 끝에서 천천히, 중간은 빠르게
    ));

    //다음 질문 이동 애니메이션
    _nextQuestionAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  //상태 해제 함수
  @override
  void dispose() {
    _animationController.dispose();//애니메이션 컨트롤러 해제
    super.dispose();
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) { // 현재 질문이 마지막이 아니라면
      _animationController.forward().then((_) { // forward: 애니메이션 실행, then: 애니메이션 후 실행할 동작 정의
        setState(() {
          currentQuestionIndex++;
          _animationController.reset();// 다음 번 애니메이션 실행 시 준비 상태로 만듦
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), //좌우 패딩
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // 좌우 중앙에 정렬
            children: [
              // 설문조사 제목
              const SizedBox(height: 32),
              const Text(
                '사용자에 대해 알려주세요!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '답변을 입력하면 사용자의 하루 패턴을\n상세하게 이용할 수 있어요!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              //설문조사 진행 상황 확인 점
              Row(
                mainAxisAlignment: MainAxisAlignment.center,//좌우 중앙에 정렬
                children: List.generate(
                  3, // 3개의 위젯 생성(index로 각 위젯 속성 다르게 가능)
                      (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4), // 점 사이 간격
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,//점을 원형으로
                      color: index <= currentQuestionIndex
                          ? Colors.grey[500] // 넘어간 질문, 현재 질문은 어두운 회색
                          : Colors.grey[300], // 아니면 밝은 회색
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              //애니메이션 실행
              Expanded( // 부모 위젯 내 가용 공간을 모두 차지
                child: Stack( // 여러 위젯을 겹침
                  children: [

                    // 현재 질문을 화면에 준비
                    SlideTransition(// 위젯이 지정된 위치로 슬라이드되면서 나타남
                      position: _currentQuestionAnimation,
                      child: _buildQuestionWidget(currentQuestionIndex), // 질문 내용 표시
                    ),

                    //다음 질문을 화면에 준비
                    if (currentQuestionIndex < questions.length - 1)
                      SlideTransition(
                        position: _nextQuestionAnimation,
                        child: _buildQuestionWidget(currentQuestionIndex + 1),
                      ),
                  ],
                ),
              ),

              // 저장 버튼
              SizedBox(
                width: double.infinity, // 화면의 전체 너비의 크기
                child: ElevatedButton( // 사용자가 누르면 상호작용 가능한 버튼
                  onPressed: () { // 버튼 눌렀을 때 실행될 동작
                    // Implement save functionality
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    elevation: 0, // 그림자 없음
                    shape: RoundedRectangleBorder( // 버튼 모서리 둥글게
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '저장하기',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  //현재 질문의 답변 옵션의 드롭다운 메뉴 생성
  Widget _buildQuestionWidget(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questions[index]['prompt'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildDropdown(index),
      ],
    );
  }

  Widget _buildDropdown(int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),

      child: DropdownButtonHideUnderline(// 드롭다운 메뉴의 기본 밑줄 숨김
        child: DropdownButton<String>( // 드롭다운 메뉴 정의
          value: questions[index]['value'] ?? questions[index]['options'][0],
          icon: const Icon(Icons.keyboard_arrow_down),
          iconSize: 24,
          elevation: 16,
          style: const TextStyle(color: Colors.black),

          onChanged: (String? newValue) { // 사용자가 선택 항목을 변경했을 때 실행
            setState(() { // 상태 업데이트
              questions[index]['value'] = newValue!;


              Future.delayed(const Duration(milliseconds: 300), () { // 잠시 대기
                _nextQuestion(); //다음 질문으로 전환
              });
            });
          },

          //드롭다운 항목 정의
          items: questions[index]['options']
              .map<DropdownMenuItem<String>>((String value) { //
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}