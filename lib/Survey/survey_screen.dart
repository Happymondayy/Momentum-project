import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/components/dropdown_menu.dart';
import 'package:momentum_planner/Survey/components/survey_header.dart';
import 'package:momentum_planner/Survey/components/progress_dots.dart';
import 'package:momentum_planner/Survey/models/question_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SurveyScreen extends StatefulWidget {
  final String? param1;
  final String? param2;
  SurveyScreen({Key? key, this.param1, this.param2}) : super(key: key);



  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> with SingleTickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> _saveUserData_() async {
    String email = widget.param1!;
    String password = widget.param2!;

    if (email.isEmpty || password.isEmpty) {
      print("이메일 또는 비밀번호를 입력하세요.");
      return;
    }

    try {
      // Firestore에 저장할 사용자 데이터를 만들기
      Map<String, dynamic> userData = {
        'email': email,
        'password': password, // 보안상 실제 앱에서는 비밀번호를 해싱해서 저장해야 함!
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 각 질문에 대한 선택지를 Firestore에 추가
      for (int i = 0; i < questions.length; i++) {
        String questionKey = 'question_${i + 1}'; // 질문의 고유 키 생성
        userData[questionKey] = questions[i].value; // 선택된 값 저장
      }

      // Firestore에 데이터 추가
      await _firestore.collection('user').add(userData);

      print("사용자 데이터 저장 완료: 이메일 - $email");
    } catch (e) {
      print('Firestore 오류: $e');
    }
  }


  int activeQuestionIndex = 0;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  late List<QuestionModel> questions;
  bool allAnswered = false; // 모든 질문에 답변이 완료되었는지 확인하는 변수

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 애니메이션 컨트롤러 초기화 - 더 부드러운 애니메이션을 위해 시간 증가
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 부드러운 곡선 사용
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),// Curves.easeOutCubic: 애니메이션이 천천히 시작하고 빠르게 진행
    );

    // 질문 초기화
    questions = [
      QuestionModel(
        prompt: '활동하기 가장 편한 시간대는 언제인가요?',
        value: '아침',
        options: ['아침', '점심', '저녁', '밤'],
        isActive: true, // 첫 번째 질문은 활성화
      ),
      QuestionModel(
        prompt: '평소 수면 시간이 어떻게 되나요?',
        value: 'PM 11:00 ~ AM 07:00',
        options: ['PM 11:00 ~ AM 07:00', 'AM 07:00 ~ PM 03:00', 'PM 03:00 ~ PM 11:00'],
      ),
      QuestionModel(
        prompt: '작업 중 얼마나 자주 휴식을 취하나요?',
        value: '1시간마다',
        options: ['30분마다', '1시간마다', '2시간마다', '3시간이상'],
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 모든 질문이 답변되었는지 확인하고 상태 업데이트
  void _updateAllAnsweredState() {
    setState(() {
      allAnswered = questions.every((q) => q.state);
    });
  }

  void _activateNextQuestion() {
    if (activeQuestionIndex < questions.length - 1) { //마지막 질문이 아니라면
      setState(() {
        // 현재 질문 완료 표시
        questions[activeQuestionIndex].state = true;

        // 다음 질문 활성화
        activeQuestionIndex++;
        questions[activeQuestionIndex].isActive = true;

        // Start the animation
        _animationController.reset(); //animationCotroller를 초기화
        _animationController.forward(); //animationCotroller를 다시 실행
      });


      _updateAllAnsweredState(); // 질문 상태 갱신
    } else { // 마지막 질문이라면
      setState(() {
        questions[activeQuestionIndex].state = true;
      });


      _updateAllAnsweredState(); // 최종 상태 갱신
    }
  }

  void _activateQuestion(int index) {
    if (index <= activeQuestionIndex) {
      setState(() {
        // 선택된 질문을 활성화
        activeQuestionIndex = index;

        // 선택된 질문까지 모든 질문 활성화
        for (int i = 0; i < questions.length; i++) {
          questions[i].isActive = i <= index;
        }

        // 애니메이션 시작
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // 메인 콘텐츠 영역 - 질문들 중앙 배치
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        // 상단 여백
                        Expanded(flex: 1, child: Container()),

                        // 헤더 및 질문 그룹
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 헤더
                            SurveyHeader(),
                            const SizedBox(height: 16),

                            // 진행 상태 점
                            ProgressDots(
                              totalQuestions: questions.length,
                              currentQuestionIndex: activeQuestionIndex,
                              activeColor: const Color(0xFF6200EE),
                              inactiveColor: Colors.grey.shade300,
                              activeDotSize: 12.0,
                              inactiveDotSize: 8.0,
                              spacing: 10.0,
                            ),
                            const SizedBox(height: 24),

                            // 질문 목록
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: questions.length,
                              itemBuilder: (context, index) {
                                final question = questions[index];

                                // 활성화된 질문 이후의 질문은 숨김 처리
                                if (index > activeQuestionIndex) {
                                  return const SizedBox.shrink();
                                }

                                // 애니메이션 효과 적용
                                double translateY = 0;
                                double opacity = 1.0;

                                if (index == activeQuestionIndex && index > 0) {
                                  // 새로 활성화된 질문
                                  opacity = _animation.value;
                                  translateY = 40.0 * (1.0 - _animation.value);
                                } else if (index < activeQuestionIndex) {
                                  // 이전 질문들
                                  translateY = -10.0 * _animation.value;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: opacity,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeOutCubic,
                                      transform: Matrix4.translationValues(0, translateY, 0),
                                      child: GestureDetector(
                                        onTap: () => _activateQuestion(index),
                                        child: CustomDropdown(
                                          prompt: question.prompt,
                                          value: question.value,
                                          options: question.options,
                                          state: question.state,
                                          isActive: question.isActive,
                                          onChanged: (value) {
                                            setState(() {
                                              question.value = value;
                                              question.state = true;
                                            });

                                            // 질문 상태 업데이트
                                            _updateAllAnsweredState();

                                            if (index == activeQuestionIndex) {
                                              _activateNextQuestion();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        // 하단 여백
                        Expanded(flex: 1, child: Container()),
                      ],
                    );
                  },
                ),
              ),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (allAnswered) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('저장되었습니다!')),

                      );
                      _saveUserData_();

                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('모든 질문에 답변해주세요.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: allAnswered
                        ? const Color(0xFFCFCFFF) // 활성화 색상
                        : Colors.grey[200],      // 비활성화 색상
                    foregroundColor: allAnswered
                        ? Colors.white // 활성화 색상
                        : Colors.black,      // 비활성화 색상
                    elevation: 0,
                    shape: RoundedRectangleBorder(
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
}
