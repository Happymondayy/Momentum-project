import 'package:flutter/material.dart';
import 'package:momentum_planner/Survey/components/dropdown_menu.dart';
import 'package:momentum_planner/Survey/components/survey_header.dart';
import 'package:momentum_planner/Survey/components/progress_dots.dart';
import 'package:momentum_planner/Survey/models/question_model.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({Key? key}) : super(key: key);

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> with SingleTickerProviderStateMixin {
  int activeQuestionIndex = 0;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  late List<QuestionModel> questions;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 애니메이션 컨트롤러 초기화 - 더 부드러운 애니메이션을 위해 시간 증가
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 부드러운 곡선 사용
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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

  void _activateNextQuestion() {
    if (activeQuestionIndex < questions.length - 1) {
      setState(() {
        // 현재 질문 완료 표시
        questions[activeQuestionIndex].state = true;

        // 다음 질문 활성화
        activeQuestionIndex++;
        questions[activeQuestionIndex].isActive = true;

        // Start the animation
        _animationController.reset();
        _animationController.forward();
      });
    } else {
      // Last question completed
      setState(() {
        questions[activeQuestionIndex].state = true;
      });
    }
  }

  void _activateQuestion(int index) {
    if (index <= activeQuestionIndex) {
      setState(() {
        // Set the clicked question as active
        activeQuestionIndex = index;

        // Make all questions active up to the current index
        for (int i = 0; i < questions.length; i++) {
          questions[i].isActive = i <= index;
        }

        // Start the animation
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
              // Main content area with centered questions
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        // 상단 여백 (질문들을 화면 중앙에 배치하기 위함)
                        Expanded(
                          flex: 1,
                          child: Container(),
                        ),

                        // 헤더와 질문 그룹을 함께 움직이도록 같은 Column 안에 배치
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 헤더
                            SurveyHeader(),
                            const SizedBox(height: 16),

                            // 진행 상태 점 표시 (헤더와 첫 번째 질문 사이)
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

                                // 활성화된 질문 이후의 질문들은 보이지 않게 처리
                                if (index > activeQuestionIndex) {
                                  return const SizedBox.shrink();
                                }

                                // 애니메이션 효과 적용
                                double translateY = 0;
                                double opacity = 1.0;

                                // 모든 질문에 대한 애니메이션 효과 적용
                                if (index == activeQuestionIndex && index > 0) {
                                  // 새로 활성화된 질문은 아래에서 부드럽게 올라옴
                                  opacity = _animation.value;
                                  translateY = 40.0 * (1.0 - _animation.value); // 더 큰 이동 거리
                                } else if (index < activeQuestionIndex) {
                                  // 이전 질문들은 위로 약간 이동
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

                        // 하단 여백 (질문들을 화면 중앙에 배치하기 위함)
                        Expanded(
                          flex: 1,
                          child: Container(),
                        ),
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
                    // 모든 질문이 답변되었는지 확인
                    bool allAnswered = questions.every((q) => q.state);
                    if (allAnswered) {
                      // 저장 기능 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('저장되었습니다!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('모든 질문에 답변해주세요.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
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